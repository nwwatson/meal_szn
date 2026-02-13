import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  open() {
    this.containerTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"
  }

  close() {
    this.containerTarget.classList.add("hidden")
    document.body.style.overflow = ""
  }
}
