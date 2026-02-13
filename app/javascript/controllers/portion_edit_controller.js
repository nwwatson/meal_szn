import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "input"]
  static values = { url: String }

  edit() {
    this.displayTarget.classList.add("hidden")
    this.inputTarget.classList.remove("hidden")
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  save(event) {
    if (event.type === "keydown" && event.key === "Enter") {
      event.preventDefault()
    }

    const newServings = parseFloat(this.inputTarget.value)
    if (isNaN(newServings) || newServings <= 0) {
      this.cancel()
      return
    }

    this.inputTarget.classList.add("hidden")
    this.displayTarget.classList.remove("hidden")
    this.displayTarget.textContent = newServings % 1 === 0 ? Math.round(newServings) : newServings

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({ portion: { servings: newServings } })
    }).then(response => {
      if (!response.ok) {
        // Revert on error
        location.reload()
      }
    })
  }

  cancel() {
    this.inputTarget.classList.add("hidden")
    this.displayTarget.classList.remove("hidden")
  }
}
