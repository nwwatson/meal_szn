import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  renumber() {
    // Use setTimeout(0) to run after the current Stimulus action chain completes,
    // ensuring nested-form#add has inserted new DOM elements before we query them.
    setTimeout(() => {
      const wrappers = this.element.querySelectorAll(".nested-form-wrapper")
      let step = 1

      wrappers.forEach((wrapper) => {
        if (wrapper.style.display === "none") return

        const input = wrapper.querySelector("input[name*='step_number']")
        if (input) {
          input.value = step
          step++
        }
      })
    }, 0)
  }
}
