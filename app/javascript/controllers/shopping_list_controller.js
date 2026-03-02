import { Controller } from "@hotwired/stimulus"

const PENDING_TOGGLES_KEY = "mealsz_pending_toggles"

export default class extends Controller {
  static targets = ["uncheckedList", "checkedList", "uncheckedSection", "checkedSection",
                     "uncheckedCount", "checkedCount", "progressBar", "statusText"]

  connect() {
    this.onlineHandler = () => this.syncPendingToggles()
    window.addEventListener("online", this.onlineHandler)

    // Sync any queued toggles from a previous offline session
    if (navigator.onLine) this.syncPendingToggles()

    // Proactively cache this shopping list page for offline use
    if ("serviceWorker" in navigator && navigator.serviceWorker.controller) {
      navigator.serviceWorker.controller.postMessage({
        type: "CACHE_SHOPPING_LIST",
        url: window.location.href
      })
    }

    this.updateSyncBanner()
  }

  disconnect() {
    window.removeEventListener("online", this.onlineHandler)
  }

  async toggleItem(event) {
    const row = event.currentTarget
    const url = row.dataset.toggleUrl
    const itemId = row.dataset.itemId
    if (!url) return

    // Prevent double-taps
    if (row.dataset.toggling === "true") return
    row.dataset.toggling = "true"

    if (!navigator.onLine) {
      // Offline: toggle optimistically and queue for sync
      const currentlyChecked = row.closest("[data-shopping-list-target='checkedList']") !== null
      this.queueToggle(url, itemId)
      this.animateToggle(row, !currentlyChecked)
      return
    }

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

    try {
      const response = await fetch(url, {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": csrfToken,
          "Accept": "application/json"
        }
      })

      const data = await response.json()
      this.animateToggle(row, data.checked)
    } catch (e) {
      // Network error — queue for sync and toggle optimistically
      const currentlyChecked = row.closest("[data-shopping-list-target='checkedList']") !== null
      this.queueToggle(url, itemId)
      this.animateToggle(row, !currentlyChecked)
    }
  }

  queueToggle(url, itemId) {
    const pending = JSON.parse(localStorage.getItem(PENDING_TOGGLES_KEY) || "[]")
    // If there's already a pending toggle for this item, they cancel out
    const existingIndex = pending.findIndex((t) => t.itemId === itemId)
    if (existingIndex !== -1) {
      pending.splice(existingIndex, 1)
    } else {
      pending.push({ url, itemId, timestamp: Date.now() })
    }
    localStorage.setItem(PENDING_TOGGLES_KEY, JSON.stringify(pending))
    this.updateSyncBanner()
  }

  async syncPendingToggles() {
    const pending = JSON.parse(localStorage.getItem(PENDING_TOGGLES_KEY) || "[]")
    if (pending.length === 0) return

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    const remaining = []

    for (const toggle of pending) {
      try {
        await fetch(toggle.url, {
          method: "PATCH",
          headers: {
            "X-CSRF-Token": csrfToken,
            "Accept": "application/json"
          }
        })
      } catch (e) {
        remaining.push(toggle)
      }
    }

    if (remaining.length > 0) {
      localStorage.setItem(PENDING_TOGGLES_KEY, JSON.stringify(remaining))
    } else {
      localStorage.removeItem(PENDING_TOGGLES_KEY)
    }
    this.updateSyncBanner()
  }

  animateToggle(row, isNowChecked) {
    const checkbox = row.querySelector("[data-checkbox]")
    const text = row.querySelector("[data-item-text]")

    if (isNowChecked) {
      // Flash green background briefly
      row.classList.add("bg-green-50")
      checkbox.innerHTML = this.checkedSvg
      checkbox.classList.remove("border-warm-300")
      checkbox.classList.add("border-primary-500", "bg-primary-500")
      text.classList.add("line-through", "text-warm-400")
      text.classList.remove("text-warm-900")

      // Move to checked section after delay
      setTimeout(() => {
        row.classList.add("opacity-0", "-translate-x-4")
        setTimeout(() => {
          this.moveToSection(row, this.checkedListTarget)
          row.classList.remove("opacity-0", "-translate-x-4", "bg-green-50")
          row.dataset.toggling = "false"
          this.updateCounts()
        }, 250)
      }, 400)
    } else {
      // Uncheck animation
      checkbox.innerHTML = ""
      checkbox.classList.remove("border-primary-500", "bg-primary-500")
      checkbox.classList.add("border-warm-300")
      text.classList.remove("line-through", "text-warm-400")
      text.classList.add("text-warm-900")

      row.classList.add("opacity-0", "translate-x-4")
      setTimeout(() => {
        this.moveToSection(row, this.uncheckedListTarget)
        row.classList.remove("opacity-0", "translate-x-4")
        row.dataset.toggling = "false"
        this.updateCounts()
      }, 250)
    }
  }

  moveToSection(row, targetList) {
    // Insert alphabetically
    const itemName = row.querySelector("[data-item-text]").textContent.trim().toLowerCase()
    const items = targetList.querySelectorAll("[data-item-row]")
    let inserted = false

    for (const existing of items) {
      const existingName = existing.querySelector("[data-item-text]").textContent.trim().toLowerCase()
      if (itemName < existingName) {
        targetList.insertBefore(row, existing)
        inserted = true
        break
      }
    }

    if (!inserted) {
      targetList.appendChild(row)
    }

    // Show/hide sections based on content
    this.updateSectionVisibility()
  }

  updateSectionVisibility() {
    const uncheckedCount = this.uncheckedListTarget.querySelectorAll("[data-item-row]").length
    const checkedCount = this.checkedListTarget.querySelectorAll("[data-item-row]").length

    this.uncheckedSectionTarget.classList.toggle("hidden", uncheckedCount === 0)
    this.checkedSectionTarget.classList.toggle("hidden", checkedCount === 0)
  }

  updateCounts() {
    const uncheckedCount = this.uncheckedListTarget.querySelectorAll("[data-item-row]").length
    const checkedCount = this.checkedListTarget.querySelectorAll("[data-item-row]").length
    const total = uncheckedCount + checkedCount

    this.uncheckedCountTarget.textContent = `To Buy (${uncheckedCount})`
    this.checkedCountTarget.textContent = `Checked Off (${checkedCount})`
    this.statusTextTarget.textContent = `${checkedCount} of ${total} items checked`

    if (total > 0) {
      const pct = Math.round((checkedCount / total) * 100)
      this.progressBarTarget.style.width = `${pct}%`
    }
  }

  updateSyncBanner() {
    const banner = document.getElementById("sync-pending-banner")
    if (!banner) return
    const pending = JSON.parse(localStorage.getItem(PENDING_TOGGLES_KEY) || "[]")
    banner.classList.toggle("hidden", pending.length === 0)
  }

  get checkedSvg() {
    return '<svg class="w-3.5 h-3.5 text-white check-pop" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"/></svg>'
  }
}
