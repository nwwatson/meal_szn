import { Controller } from "@hotwired/stimulus"

// Counts down from a given number of minutes, updating a text display.
export default class extends Controller {
  static targets = ["display"]
  static values = { minutes: { type: Number, default: 15 } }

  connect() {
    this.remaining = this.minutesValue * 60
    this.update()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }

  tick() {
    this.remaining--
    if (this.remaining <= 0) {
      this.remaining = 0
      clearInterval(this.timer)
    }
    this.update()
  }

  update() {
    const m = Math.floor(this.remaining / 60)
    const s = this.remaining % 60
    this.displayTarget.textContent = `${m}:${s.toString().padStart(2, "0")}`

    if (this.remaining <= 60) {
      this.displayTarget.classList.add("text-red-500", "font-semibold")
    }
  }
}
