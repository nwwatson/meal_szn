import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { baseUrl: String }

  connect() {
    this.element.addEventListener("dragstart", this.dragStart.bind(this))
    this.element.addEventListener("dragover", this.dragOver.bind(this))
    this.element.addEventListener("drop", this.drop.bind(this))
    this.element.addEventListener("dragend", this.dragEnd.bind(this))
    this.element.addEventListener("dragleave", this.dragLeave.bind(this))
  }

  dragStart(event) {
    const card = event.target.closest("[data-meal-id]")
    if (!card) return

    event.dataTransfer.setData("text/plain", card.dataset.mealId)
    event.dataTransfer.effectAllowed = "move"
    card.classList.add("opacity-50")
  }

  dragOver(event) {
    const zone = event.target.closest("[data-drop-zone]")
    if (!zone) return

    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    zone.classList.add("bg-primary-100/50", "ring-2", "ring-primary-300")
  }

  dragLeave(event) {
    const zone = event.target.closest("[data-drop-zone]")
    if (!zone) return

    zone.classList.remove("bg-primary-100/50", "ring-2", "ring-primary-300")
  }

  drop(event) {
    event.preventDefault()
    const zone = event.target.closest("[data-drop-zone]")
    if (!zone) return

    zone.classList.remove("bg-primary-100/50", "ring-2", "ring-primary-300")

    const mealId = event.dataTransfer.getData("text/plain")
    if (!mealId) return

    const targetDayId = zone.dataset.dayId
    const targetMealType = zone.dataset.mealType

    this.moveMeal(mealId, targetDayId, targetMealType)
  }

  dragEnd(event) {
    const card = event.target.closest("[data-meal-id]")
    if (card) card.classList.remove("opacity-50")

    this.element.querySelectorAll("[data-drop-zone]").forEach((zone) => {
      zone.classList.remove("bg-primary-100/50", "ring-2", "ring-primary-300")
    })
  }

  async moveMeal(mealId, targetDayId, targetMealType) {
    const url = `${this.baseUrlValue}/${mealId}/move`
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

    try {
      const response = await fetch(url, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({
          target_day_id: targetDayId,
          target_meal_type: targetMealType
        })
      })

      if (response.ok) {
        window.location.reload()
      } else {
        console.error("Failed to move meal:", await response.text())
      }
    } catch (error) {
      console.error("Error moving meal:", error)
    }
  }
}
