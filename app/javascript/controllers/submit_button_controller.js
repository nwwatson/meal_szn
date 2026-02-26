import { Controller } from "@hotwired/stimulus"

// Shows a loading spinner inside a submit button on form submission.
export default class extends Controller {
  static targets = ["button", "label", "spinner"]

  submit() {
    this.buttonTarget.disabled = true
    this.labelTarget.classList.add("opacity-0")
    this.spinnerTarget.classList.remove("hidden")
  }
}
