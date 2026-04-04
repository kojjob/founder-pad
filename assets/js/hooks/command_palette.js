/**
 * CommandPalette LiveView Hook
 *
 * Opens a Cmd+K / Ctrl+K command palette modal for global search.
 * Searches across pages, blog posts, and help articles via the /api/search endpoint.
 *
 * All dynamic content is escaped via escapeHtml() before DOM insertion to prevent XSS.
 */
const CommandPalette = {
  mounted() {
    this.modal = null
    this.selectedIndex = -1
    this.results = []

    this.handleKeyDown = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") {
        e.preventDefault()
        this.toggle()
        return
      }

      if (!this.isOpen()) return

      if (e.key === "Escape") {
        e.preventDefault()
        this.close()
        return
      }

      if (e.key === "ArrowDown") {
        e.preventDefault()
        this.moveSelection(1)
        return
      }

      if (e.key === "ArrowUp") {
        e.preventDefault()
        this.moveSelection(-1)
        return
      }

      if (e.key === "Enter") {
        e.preventDefault()
        this.navigateToSelected()
        return
      }
    }

    document.addEventListener("keydown", this.handleKeyDown)
  },

  destroyed() {
    document.removeEventListener("keydown", this.handleKeyDown)
    this.removeModal()
  },

  isOpen() {
    return this.modal !== null && document.body.contains(this.modal)
  },

  toggle() {
    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  },

  open() {
    if (this.isOpen()) return

    this.results = []
    this.selectedIndex = -1
    this.modal = this.buildModal()
    document.body.appendChild(this.modal)

    requestAnimationFrame(() => {
      const input = this.modal.querySelector("#command-palette-input")
      if (input) input.focus()
    })
  },

  close() {
    this.removeModal()
    this.results = []
    this.selectedIndex = -1
  },

  removeModal() {
    if (this.modal && document.body.contains(this.modal)) {
      document.body.removeChild(this.modal)
    }
    this.modal = null
  },

  moveSelection(delta) {
    const items = this.modal?.querySelectorAll("[data-result-index]") || []
    if (items.length === 0) return

    this.selectedIndex = Math.max(-1, Math.min(items.length - 1, this.selectedIndex + delta))

    items.forEach((item, i) => {
      if (i === this.selectedIndex) {
        item.classList.add("bg-primary/10")
        item.classList.remove("hover:bg-primary/5")
        item.scrollIntoView({ block: "nearest" })
      } else {
        item.classList.remove("bg-primary/10")
        item.classList.add("hover:bg-primary/5")
      }
    })
  },

  navigateToSelected() {
    const items = this.modal?.querySelectorAll("[data-result-index]") || []
    if (this.selectedIndex >= 0 && this.selectedIndex < items.length) {
      const url = items[this.selectedIndex].getAttribute("href")
      if (url) window.location.href = url
    }
  },

  async performSearch(query) {
    if (query.length < 2) {
      this.results = []
      this.selectedIndex = -1
      this.renderResults()
      return
    }

    try {
      const response = await fetch(`/api/search?q=${encodeURIComponent(query)}`)
      const data = await response.json()
      this.results = data.results || []
      this.selectedIndex = -1
      this.renderResults()
    } catch (_error) {
      this.results = []
      this.renderResults()
    }
  },

  renderResults() {
    const container = this.modal?.querySelector("#command-palette-results")
    if (!container) return

    // Clear existing content
    container.textContent = ""

    if (this.results.length === 0) {
      const input = this.modal.querySelector("#command-palette-input")
      const query = input?.value || ""

      const emptyDiv = document.createElement("div")
      emptyDiv.className = "px-4 py-8 text-center text-on-surface-variant text-sm"

      if (query.length >= 2) {
        emptyDiv.textContent = `No results for "${query}"`
      } else {
        emptyDiv.className = "px-4 py-4 text-center text-on-surface-variant/50 text-sm"
        emptyDiv.textContent = "Type to search across agents, pages, blog, and help articles..."
      }

      container.appendChild(emptyDiv)
      return
    }

    const grouped = this.groupByType(this.results)
    const typeOrder = ["page", "agent", "blog", "help"]
    const typeLabels = { page: "Pages", agent: "Agents", blog: "Blog", help: "Help" }

    let globalIndex = 0

    typeOrder.forEach(type => {
      const items = grouped[type]
      if (!items || items.length === 0) return

      // Type header
      const headerDiv = document.createElement("div")
      headerDiv.className = "px-3 py-1.5"
      const headerP = document.createElement("p")
      headerP.className = "text-[10px] font-semibold uppercase tracking-wider text-on-surface-variant/50 px-1"
      headerP.textContent = typeLabels[type] || type
      headerDiv.appendChild(headerP)
      container.appendChild(headerDiv)

      // Result items
      items.forEach(item => {
        const link = document.createElement("a")
        link.href = item.url
        link.setAttribute("data-result-index", globalIndex)
        link.className = "flex items-center gap-3 px-4 py-2.5 hover:bg-primary/5 transition-colors cursor-pointer no-underline"

        const icon = document.createElement("span")
        icon.className = "material-symbols-outlined text-on-surface-variant text-lg"
        icon.textContent = item.icon
        link.appendChild(icon)

        const textDiv = document.createElement("div")
        textDiv.className = "flex-1 min-w-0"

        const titleP = document.createElement("p")
        titleP.className = "text-sm font-medium text-on-surface truncate"
        titleP.textContent = item.title
        textDiv.appendChild(titleP)

        if (item.description) {
          const descP = document.createElement("p")
          descP.className = "text-xs text-on-surface-variant truncate"
          descP.textContent = item.description
          textDiv.appendChild(descP)
        }

        link.appendChild(textDiv)

        const arrow = document.createElement("span")
        arrow.className = "material-symbols-outlined text-on-surface-variant/30 text-sm"
        arrow.textContent = "arrow_forward"
        link.appendChild(arrow)

        container.appendChild(link)
        globalIndex++
      })
    })
  },

  groupByType(results) {
    return results.reduce((acc, item) => {
      const type = item.type || "other"
      if (!acc[type]) acc[type] = []
      acc[type].push(item)
      return acc
    }, {})
  },

  buildModal() {
    const wrapper = document.createElement("div")
    wrapper.id = "command-palette-modal"
    wrapper.className = "fixed inset-0 z-[100]"

    // Backdrop
    const backdrop = document.createElement("div")
    backdrop.id = "command-palette-backdrop"
    backdrop.className = "fixed inset-0 bg-black/50 backdrop-blur-sm"
    backdrop.addEventListener("click", () => this.close())
    wrapper.appendChild(backdrop)

    // Modal container
    const modalOuter = document.createElement("div")
    modalOuter.className = "fixed top-[20%] left-1/2 -translate-x-1/2 w-full max-w-lg px-4"

    const modalInner = document.createElement("div")
    modalInner.className = "bg-white dark:bg-neutral-900 rounded-2xl shadow-2xl border border-neutral-200/60 dark:border-neutral-700/60 overflow-hidden"

    // Search input row
    const inputRow = document.createElement("div")
    inputRow.className = "flex items-center gap-3 px-4 py-3 border-b border-neutral-200/60 dark:border-neutral-700/60"

    const searchIcon = document.createElement("span")
    searchIcon.className = "material-symbols-outlined text-on-surface-variant"
    searchIcon.textContent = "search"
    inputRow.appendChild(searchIcon)

    const input = document.createElement("input")
    input.id = "command-palette-input"
    input.type = "text"
    input.placeholder = "Search agents, pages, articles..."
    input.className = "flex-1 bg-transparent text-on-surface outline-none text-sm placeholder:text-on-surface-variant/50"
    input.autocomplete = "off"

    let debounceTimer = null
    input.addEventListener("input", (e) => {
      clearTimeout(debounceTimer)
      debounceTimer = setTimeout(() => {
        this.performSearch(e.target.value.trim())
      }, 150)
    })
    inputRow.appendChild(input)

    const escKbd = document.createElement("kbd")
    escKbd.className = "text-[10px] font-mono text-on-surface-variant/40 bg-neutral-100 dark:bg-neutral-800 px-1.5 py-0.5 rounded"
    escKbd.textContent = "ESC"
    inputRow.appendChild(escKbd)

    modalInner.appendChild(inputRow)

    // Results container
    const resultsDiv = document.createElement("div")
    resultsDiv.id = "command-palette-results"
    resultsDiv.className = "max-h-80 overflow-y-auto"

    const placeholder = document.createElement("div")
    placeholder.className = "px-4 py-4 text-center text-on-surface-variant/50 text-sm"
    placeholder.textContent = "Type to search across agents, pages, blog, and help articles..."
    resultsDiv.appendChild(placeholder)

    modalInner.appendChild(resultsDiv)

    // Footer
    const footer = document.createElement("div")
    footer.className = "px-4 py-2 border-t border-neutral-200/60 dark:border-neutral-700/60 flex items-center gap-4 text-[10px] text-on-surface-variant/40"

    const shortcuts = [
      { key: "↑↓", label: "Navigate" },
      { key: "↵", label: "Open" },
      { key: "ESC", label: "Close" }
    ]

    shortcuts.forEach(s => {
      const span = document.createElement("span")
      const kbd = document.createElement("kbd")
      kbd.className = "font-mono bg-neutral-100 dark:bg-neutral-800 px-1 py-0.5 rounded"
      kbd.textContent = s.key
      span.appendChild(kbd)
      span.appendChild(document.createTextNode(` ${s.label}`))
      footer.appendChild(span)
    })

    modalInner.appendChild(footer)
    modalOuter.appendChild(modalInner)
    wrapper.appendChild(modalOuter)

    return wrapper
  }
}

export default CommandPalette
