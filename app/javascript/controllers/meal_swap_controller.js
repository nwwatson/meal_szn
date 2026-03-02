import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]
  static values = { url: String }

  async open(event) {
    event.preventDefault()
    event.stopPropagation()

    // Close any other open panels
    document.querySelectorAll("[data-meal-swap-target='panel']").forEach(p => {
      if (p !== this.panelTarget) p.innerHTML = ""
    })

    if (this.panelTarget.innerHTML.trim()) {
      this.close()
      return
    }

    const response = await fetch(this.urlValue, {
      headers: { "Accept": "text/html", "X-Requested-With": "XMLHttpRequest" }
    })

    if (response.ok) {
      this.panelTarget.innerHTML = await response.text()
    }
  }

  close() {
    this.panelTarget.innerHTML = ""
  }
}
