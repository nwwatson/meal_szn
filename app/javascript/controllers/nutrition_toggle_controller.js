import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mode", "manualFields", "autoMessage"]

  connect() {
    this.toggle()
  }

  toggle() {
    const isAuto = this.modeTarget.value === "auto"

    this.manualFieldsTarget.classList.toggle("hidden", isAuto)
    this.autoMessageTarget.classList.toggle("hidden", !isAuto)

    // Disable hidden inputs to prevent stale data submission
    const manualInputs = this.manualFieldsTarget.querySelectorAll("input, select")
    manualInputs.forEach(input => {
      input.disabled = isAuto
    })
  }
}
