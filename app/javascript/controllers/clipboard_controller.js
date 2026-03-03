import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button", "feedback"]

  async copy() {
    // If source has data-item-text children, collect those lines (shopping list mode)
    const items = this.sourceTarget.querySelectorAll("[data-item-text]")
    let text

    if (items.length > 0) {
      const lines = Array.from(items).map(el => el.textContent.trim())
      if (lines.length === 0) return
      text = lines.join("\n")
    } else {
      // Otherwise copy the source element's text content directly
      text = this.sourceTarget.textContent.trim()
      if (!text) return
    }

    try {
      await navigator.clipboard.writeText(text)
      this.showFeedback()
    } catch (e) {
      // Fallback for older browsers
      const textarea = document.createElement("textarea")
      textarea.value = text
      textarea.style.position = "fixed"
      textarea.style.opacity = "0"
      document.body.appendChild(textarea)
      textarea.select()
      document.execCommand("copy")
      document.body.removeChild(textarea)
      this.showFeedback()
    }
  }

  showFeedback() {
    const original = this.feedbackTarget.textContent
    this.feedbackTarget.textContent = "Copied!"

    setTimeout(() => {
      this.feedbackTarget.textContent = original
    }, 1500)
  }
}
