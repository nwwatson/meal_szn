import { Controller } from "@hotwired/stimulus"

// Manages 6 individual code input boxes that combine into a hidden field.
// Auto-advances on input, supports backspace navigation and paste.
export default class extends Controller {
  static targets = ["box", "hidden"]

  connect() {
    this.boxTargets[0]?.focus()
  }

  onInput(event) {
    const box = event.target
    const value = box.value.toUpperCase().replace(/[^A-Z0-9]/g, "")
    box.value = value

    if (value && box.dataset.index < this.boxTargets.length - 1) {
      this.boxTargets[parseInt(box.dataset.index) + 1].focus()
    }

    this.syncHidden()
  }

  onKeydown(event) {
    const box = event.target
    const index = parseInt(box.dataset.index)

    if (event.key === "Backspace" && !box.value && index > 0) {
      this.boxTargets[index - 1].focus()
      this.boxTargets[index - 1].value = ""
      this.syncHidden()
    }
  }

  onPaste(event) {
    event.preventDefault()
    const text = (event.clipboardData || window.clipboardData)
      .getData("text")
      .toUpperCase()
      .replace(/[^A-Z0-9]/g, "")
      .slice(0, this.boxTargets.length)

    text.split("").forEach((char, i) => {
      if (this.boxTargets[i]) {
        this.boxTargets[i].value = char
      }
    })

    const nextEmpty = Math.min(text.length, this.boxTargets.length - 1)
    this.boxTargets[nextEmpty].focus()
    this.syncHidden()
  }

  syncHidden() {
    const code = this.boxTargets.map(b => b.value).join("")
    // Insert dash after 3rd character to match ABC-123 format
    this.hiddenTarget.value = code.length > 3
      ? code.slice(0, 3) + "-" + code.slice(3)
      : code
  }
}
