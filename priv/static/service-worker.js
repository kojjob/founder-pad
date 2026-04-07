// Service Worker for Web Push notifications
self.addEventListener('push', function(event) {
  const data = event.data ? event.data.json() : {};

  const options = {
    body: data.body || 'New notification',
    icon: data.icon || '/images/logo-icon.png',
    badge: data.badge || '/images/badge.png',
    data: data.data || {},
    vibrate: [200, 100, 200],
    tag: data.tag || 'founderpad-notification',
    renotify: true
  };

  event.waitUntil(
    self.registration.showNotification(data.title || 'FounderPad', options)
  );
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();

  const url = event.notification.data && event.notification.data.url
    ? event.notification.data.url
    : '/dashboard';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then(function(clientList) {
        for (const client of clientList) {
          if (client.url.includes(url) && 'focus' in client) {
            return client.focus();
          }
        }
        return clients.openWindow(url);
      })
  );
});
