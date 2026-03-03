import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "count"]

  selectAll() {
    this.checkboxTargets.forEach(cb => cb.checked = true)
    this.updateCount()
  }

  selectNone() {
    this.checkboxTargets.forEach(cb => cb.checked = false)
    this.updateCount()
  }

  updateCount() {
    const total = this.checkboxTargets.length
    const selected = this.checkboxTargets.filter(cb => cb.checked).length

    if (this.hasCountTarget) {
      this.countTarget.textContent = `${selected} of ${total} selected`
    }
  }
}
