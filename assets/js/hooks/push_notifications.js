const PushNotifications = {
  mounted() {
    this.setupPushButton()
  },

  setupPushButton() {
    const btn = this.el

    if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
      btn.textContent = 'Push not supported'
      btn.disabled = true
      return
    }

    // Check current permission
    if (Notification.permission === 'granted') {
      btn.textContent = 'Notifications Enabled'
      btn.classList.add('opacity-50')
      this.registerServiceWorker()
    } else if (Notification.permission === 'denied') {
      btn.textContent = 'Notifications Blocked'
      btn.disabled = true
    }

    btn.addEventListener('click', () => this.requestPermission())
  },

  async requestPermission() {
    const permission = await Notification.requestPermission()

    if (permission === 'granted') {
      await this.registerServiceWorker()
      this.el.textContent = 'Notifications Enabled'
      this.el.classList.add('opacity-50')
    }
  },

  async registerServiceWorker() {
    try {
      const registration = await navigator.serviceWorker.register('/service-worker.js')

      // Get VAPID public key from meta tag
      const vapidMeta = document.querySelector('meta[name="vapid-public-key"]')
      if (!vapidMeta) return

      const vapidPublicKey = vapidMeta.content
      const convertedKey = this.urlBase64ToUint8Array(vapidPublicKey)

      let subscription = await registration.pushManager.getSubscription()

      if (!subscription) {
        subscription = await registration.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: convertedKey
        })
      }

      // Send subscription to server via fetch
      const userId = document.querySelector('meta[name="user-id"]')?.content
      if (userId) {
        fetch('/api/push/subscribe', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            subscription: JSON.stringify(subscription),
            user_id: userId,
            device_name: navigator.userAgent.split(' ').slice(-1)[0] || 'Browser'
          })
        })
      }
    } catch (err) {
      console.error('Push registration failed:', err)
    }
  },

  urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - base64String.length % 4) % 4)
    const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/')
    const rawData = window.atob(base64)
    const outputArray = new Uint8Array(rawData.length)
    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i)
    }
    return outputArray
  }
}

export default PushNotifications
