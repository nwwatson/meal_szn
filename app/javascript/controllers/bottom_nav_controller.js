import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["popover", "plusIcon", "quickCreateBtn"]

  connect() {
    this.isOpen = false
    this.outsideClickHandler = this.closeOnOutsideClick.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClickHandler)
  }

  toggleQuickCreate() {
    if (this.isOpen) {
      this.closePopover()
    } else {
      this.openPopover()
    }
  }

  openPopover() {
    this.isOpen = true
    this.popoverTarget.classList.remove("hidden")

    requestAnimationFrame(() => {
      this.popoverTarget.classList.remove("scale-95", "opacity-0")
      this.popoverTarget.classList.add("scale-100", "opacity-100")
      this.plusIconTarget.classList.add("rotate-45")
    })

    document.addEventListener("click", this.outsideClickHandler)
  }

  closePopover() {
    this.isOpen = false
    this.popoverTarget.classList.remove("scale-100", "opacity-100")
    this.popoverTarget.classList.add("scale-95", "opacity-0")
    this.plusIconTarget.classList.remove("rotate-45")

    setTimeout(() => {
      this.popoverTarget.classList.add("hidden")
    }, 200)

    document.removeEventListener("click", this.outsideClickHandler)
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.closePopover()
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape" && this.isOpen) {
      this.closePopover()
    }
  }
}
