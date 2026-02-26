import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button", "feedback"]

  async copy() {
    const items = this.sourceTarget.querySelectorAll("[data-item-text]")
    const lines = Array.from(items).map(el => el.textContent.trim())
    const text = lines.join("\n")

    if (lines.length === 0) return

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
    this.feedbackTarget.classList.remove("hidden")
    this.feedbackTarget.classList.add("opacity-100")

    setTimeout(() => {
      this.feedbackTarget.classList.remove("opacity-100")
      this.feedbackTarget.classList.add("opacity-0")
      setTimeout(() => {
        this.feedbackTarget.classList.add("hidden")
        this.feedbackTarget.classList.remove("opacity-0")
      }, 300)
    }, 1500)
  }
}
