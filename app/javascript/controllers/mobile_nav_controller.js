import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "backdrop"]

  connect() {
    this.isOpen = false
  }

  toggle() {
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.isOpen = true
    this.drawerTarget.classList.remove("hidden")
    this.backdropTarget.classList.remove("hidden")

    // Force reflow before animating
    this.drawerTarget.offsetHeight

    requestAnimationFrame(() => {
      this.backdropTarget.classList.remove("opacity-0")
      this.backdropTarget.classList.add("opacity-100")
      this.drawerTarget.classList.remove("translate-x-full")
      this.drawerTarget.classList.add("translate-x-0")
    })
  }

  close() {
    this.isOpen = false
    this.backdropTarget.classList.remove("opacity-100")
    this.backdropTarget.classList.add("opacity-0")
    this.drawerTarget.classList.remove("translate-x-0")
    this.drawerTarget.classList.add("translate-x-full")

    setTimeout(() => {
      this.drawerTarget.classList.add("hidden")
      this.backdropTarget.classList.add("hidden")
    }, 300)
  }

  closeOnBackdrop(event) {
    if (event.target === this.backdropTarget) {
      this.close()
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape" && this.isOpen) {
      this.close()
    }
  }
}
