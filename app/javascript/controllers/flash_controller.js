import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { duration: { type: Number, default: 5000 } }

  connect() {
    // Trigger enter animation on next frame
    requestAnimationFrame(() => {
      this.element.classList.remove("opacity-0", "translate-y-[-1rem]")
      this.element.classList.add("opacity-100", "translate-y-0")
    })

    this.startTimer()
  }

  disconnect() {
    this.clearTimer()
  }

  close() {
    this.clearTimer()
    this.animateOut()
  }

  startTimer() {
    this.timer = setTimeout(() => this.animateOut(), this.durationValue)
  }

  clearTimer() {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
  }

  animateOut() {
    this.element.classList.remove("opacity-100", "translate-y-0")
    this.element.classList.add("opacity-0", "translate-y-[-1rem]")

    this.element.addEventListener("transitionend", () => {
      this.element.remove()
    }, { once: true })

    // Fallback removal if transitionend doesn't fire
    setTimeout(() => {
      if (this.element?.parentNode) {
        this.element.remove()
      }
    }, 400)
  }
}
