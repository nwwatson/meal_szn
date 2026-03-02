import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["banner"]

  connect() {
    this.updateStatus()
    this.onlineHandler = () => this.goOnline()
    this.offlineHandler = () => this.goOffline()
    window.addEventListener("online", this.onlineHandler)
    window.addEventListener("offline", this.offlineHandler)
  }

  disconnect() {
    window.removeEventListener("online", this.onlineHandler)
    window.removeEventListener("offline", this.offlineHandler)
  }

  updateStatus() {
    if (!navigator.onLine) {
      this.goOffline()
    }
  }

  goOffline() {
    this.bannerTarget.classList.remove("translate-y-full", "opacity-0")
    this.bannerTarget.classList.add("translate-y-0", "opacity-100")
  }

  goOnline() {
    this.bannerTarget.classList.add("translate-y-full", "opacity-0")
    this.bannerTarget.classList.remove("translate-y-0", "opacity-100")

    // Sync any pending offline actions
    if ("serviceWorker" in navigator && navigator.serviceWorker.controller) {
      navigator.serviceWorker.ready.then((registration) => {
        if (registration.sync) {
          registration.sync.register("sync-shopping-list").catch(() => {})
        }
      })
    }
  }
}
