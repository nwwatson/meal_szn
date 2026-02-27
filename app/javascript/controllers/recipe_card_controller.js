import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { index: Number }

  connect() {
    this.element.style.opacity = "0"
    this.element.style.transform = "translateY(16px)"

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          this.reveal()
          this.observer.unobserve(entry.target)
        }
      })
    }, { threshold: 0.1 })

    this.observer.observe(this.element)
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  reveal() {
    const delay = (this.indexValue % 12) * 80
    setTimeout(() => {
      this.element.style.transition = "opacity 0.4s ease-out, transform 0.4s ease-out"
      this.element.style.opacity = "1"
      this.element.style.transform = "translateY(0)"
    }, delay)
  }
}
