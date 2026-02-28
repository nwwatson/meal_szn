import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggleButton", "panel", "chevron", "iconWrap", "icon",
                     "chips", "specialRequests", "form", "manualSubmit", "aiSubmit"]

  connect() {
    this.active = false
    this.selectedPreferences = new Set()
  }

  toggle() {
    this.active = !this.active

    if (this.active) {
      if (this.hasPanelTarget) this.panelTarget.classList.remove("hidden")
      if (this.hasChevronTarget) this.chevronTarget.style.transform = "rotate(180deg)"
      if (this.hasToggleButtonTarget) {
        this.toggleButtonTarget.classList.remove("border-dashed", "border-warm-300")
        this.toggleButtonTarget.classList.add("border-solid", "border-primary-400", "bg-primary-50/50")
      }
      if (this.hasIconWrapTarget) {
        this.iconWrapTarget.classList.remove("bg-warm-100")
        this.iconWrapTarget.classList.add("bg-primary-100")
      }
      if (this.hasIconTarget) {
        this.iconTarget.classList.remove("text-warm-500")
        this.iconTarget.classList.add("text-primary-600")
      }
      if (this.hasManualSubmitTarget) this.manualSubmitTarget.classList.add("hidden")
      if (this.hasAiSubmitTarget) this.aiSubmitTarget.classList.remove("hidden")
    } else {
      if (this.hasPanelTarget) this.panelTarget.classList.add("hidden")
      if (this.hasChevronTarget) this.chevronTarget.style.transform = ""
      if (this.hasToggleButtonTarget) {
        this.toggleButtonTarget.classList.add("border-dashed", "border-warm-300")
        this.toggleButtonTarget.classList.remove("border-solid", "border-primary-400", "bg-primary-50/50")
      }
      if (this.hasIconWrapTarget) {
        this.iconWrapTarget.classList.add("bg-warm-100")
        this.iconWrapTarget.classList.remove("bg-primary-100")
      }
      if (this.hasIconTarget) {
        this.iconTarget.classList.add("text-warm-500")
        this.iconTarget.classList.remove("text-primary-600")
      }
      if (this.hasManualSubmitTarget) this.manualSubmitTarget.classList.remove("hidden")
      if (this.hasAiSubmitTarget) this.aiSubmitTarget.classList.add("hidden")
    }
  }

  toggleChip(event) {
    const button = event.currentTarget
    const key = button.dataset.preferenceKey
    const isSelected = this.selectedPreferences.has(key)

    if (isSelected) {
      this.selectedPreferences.delete(key)
      button.classList.remove("border-primary-500", "bg-primary-100", "text-primary-700")
      button.classList.add("border-warm-300", "bg-white", "text-warm-600")
    } else {
      this.selectedPreferences.add(key)
      button.classList.add("border-primary-500", "bg-primary-100", "text-primary-700")
      button.classList.remove("border-warm-300", "bg-white", "text-warm-600")
    }
  }

  submitWithAi() {
    const form = this.formTarget

    // Change form action to start_generate
    const currentAction = form.action
    form.action = currentAction.replace(/\/meal_plans$/, "/meal_plans/start_generate")

    // Add hidden inputs for preferences
    this.selectedPreferences.forEach(key => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "ai_preferences[]"
      input.value = key
      form.appendChild(input)
    })

    // Add special requests
    if (this.hasSpecialRequestsTarget && this.specialRequestsTarget.value.trim()) {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "ai_special_requests"
      input.value = this.specialRequestsTarget.value.trim()
      form.appendChild(input)
    }

    form.requestSubmit()
  }
}
