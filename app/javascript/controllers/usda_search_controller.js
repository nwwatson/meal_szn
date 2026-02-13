import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "results", "selection"]
  static values = { url: String }

  connect() {
    if (this.queryTarget.value.trim() !== "") {
      this.search()
    }
  }

  search() {
    const query = this.queryTarget.value.trim()
    if (query === "") {
      this.resultsTarget.innerHTML = ""
      return
    }

    fetch(`${this.urlValue}?query=${encodeURIComponent(query)}`, {
      headers: { "Accept": "text/html" }
    })
      .then(response => response.text())
      .then(html => {
        this.resultsTarget.innerHTML = html
      })
  }

  select(event) {
    const fdcId = event.currentTarget.dataset.fdcId
    this.selectionTarget.value = fdcId

    // Highlight selected card
    this.resultsTarget.querySelectorAll("[data-result-card]").forEach(card => {
      card.classList.remove("ring-2", "ring-emerald-500")
    })
    event.currentTarget.closest("[data-result-card]").classList.add("ring-2", "ring-emerald-500")
  }
}
