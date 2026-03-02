import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "chevron"]
  static values = { open: { type: Boolean, default: true } }

  toggle() {
    this.openValue = !this.openValue
    this.updateVisibility()
  }

  updateVisibility() {
    if (this.openValue) {
      this.contentTarget.style.maxHeight = this.contentTarget.scrollHeight + "px"
      this.contentTarget.style.opacity = "1"
      if (this.hasChevronTarget) this.chevronTarget.style.transform = "rotate(0deg)"
    } else {
      this.contentTarget.style.maxHeight = "0px"
      this.contentTarget.style.opacity = "0"
      if (this.hasChevronTarget) this.chevronTarget.style.transform = "rotate(-90deg)"
    }
  }

  contentTargetConnected() {
    this.contentTarget.style.transition = "max-height 0.25s ease, opacity 0.2s ease"
    this.contentTarget.style.overflow = "hidden"
    if (this.openValue) {
      this.contentTarget.style.maxHeight = "none"
      this.contentTarget.style.opacity = "1"
    } else {
      this.contentTarget.style.maxHeight = "0px"
      this.contentTarget.style.opacity = "0"
    }
  }
}
