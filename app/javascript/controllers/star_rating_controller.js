import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["star"]
  static values = { url: String, current: Number }

  rate(event) {
    const value = parseInt(event.currentTarget.dataset.value)
    const rating = value === this.currentValue ? 0 : value

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: `rating=${rating}`
    }).then(response => {
      if (response.ok) return response.text()
      throw new Error("Rating failed")
    }).then(html => {
      Turbo.renderStreamMessage(html)
    })
  }

  preview(event) {
    const hoverValue = parseInt(event.currentTarget.dataset.value)
    this.fillStars(hoverValue)
  }

  reset() {
    this.fillStars(this.currentValue)
  }

  fillStars(count) {
    this.starTargets.forEach((button, index) => {
      const svg = button.querySelector("path")
      if (index < count) {
        svg.setAttribute("fill", "currentColor")
      } else {
        svg.setAttribute("fill", "none")
      }
    })
  }
}
