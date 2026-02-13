import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name", "startDate", "endDate", "duration"]

  dateChanged() {
    this.updateName()
    this.updateDuration()
  }

  updateName() {
    if (!this.hasNameTarget || !this.hasStartDateTarget) return

    const name = this.nameTarget.value
    const startDate = this.startDateTarget.value
    if (!startDate) return

    if (name === "" || name.match(/^Week of /)) {
      const date = new Date(startDate + "T00:00:00")
      const formatted = date.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" })
      this.nameTarget.value = `Week of ${formatted}`
    }
  }

  updateDuration() {
    if (!this.hasDurationTarget || !this.hasStartDateTarget || !this.hasEndDateTarget) return

    const start = this.startDateTarget.value
    const end = this.endDateTarget.value

    if (start && end) {
      const days = Math.round((new Date(end) - new Date(start)) / (1000 * 60 * 60 * 24)) + 1
      if (days > 0) {
        this.durationTarget.textContent = `Duration: ${days} day${days === 1 ? "" : "s"}`
      } else {
        this.durationTarget.textContent = "End date must be after start date"
      }
    } else {
      this.durationTarget.textContent = ""
    }
  }
}
