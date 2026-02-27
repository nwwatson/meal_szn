import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "toggle"]

  connect() {
    this.open = false
  }

  togglePanel() {
    this.open = !this.open
    if (this.open) {
      this.panelTarget.style.maxHeight = this.panelTarget.scrollHeight + "px"
      this.panelTarget.style.opacity = "1"
    } else {
      this.panelTarget.style.maxHeight = "0"
      this.panelTarget.style.opacity = "0"
    }
  }

  clearAll(event) {
    event.preventDefault()
    const baseUrl = window.location.pathname
    Turbo.visit(baseUrl)
  }
}
