import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "backdrop", "dialog", "planSelect", "step1", "step2", "daySelect", "mealType", "servings", "submitBtn", "message"]
  static values = { recipeId: String, baseUrl: String }

  open() {
    this.containerTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"
    this.hideMessage()

    requestAnimationFrame(() => {
      if (this.hasBackdropTarget) {
        this.backdropTarget.classList.remove("opacity-0")
        this.backdropTarget.classList.add("opacity-100")
      }
      if (this.hasDialogTarget) {
        this.dialogTarget.classList.remove("opacity-0", "scale-95")
        this.dialogTarget.classList.add("opacity-100", "scale-100")
      }
    })
  }

  close() {
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.remove("opacity-100")
      this.backdropTarget.classList.add("opacity-0")
    }
    if (this.hasDialogTarget) {
      this.dialogTarget.classList.remove("opacity-100", "scale-100")
      this.dialogTarget.classList.add("opacity-0", "scale-95")
    }

    const onEnd = () => {
      this.containerTarget.classList.add("hidden")
      document.body.style.overflow = ""
      this.reset()
    }

    if (this.hasDialogTarget) {
      this.dialogTarget.addEventListener("transitionend", onEnd, { once: true })
      setTimeout(onEnd, 250)
    } else {
      onEnd()
    }
  }

  planSelected() {
    const option = this.planSelectTarget.selectedOptions[0]
    if (!option || !option.value) {
      this.step2Target.classList.add("hidden")
      return
    }

    const days = JSON.parse(option.dataset.days || "[]")
    this.daySelectTarget.innerHTML = ""
    days.forEach(day => {
      const opt = document.createElement("option")
      opt.value = day.id
      opt.textContent = day.label
      this.daySelectTarget.appendChild(opt)
    })

    this.step2Target.classList.remove("hidden")
  }

  async submit() {
    const planId = this.planSelectTarget.value
    const dayId = this.daySelectTarget.value
    const mealType = this.mealTypeTarget.value
    const servings = this.servingsTarget.value

    if (!planId || !dayId) return

    this.submitBtnTarget.disabled = true
    this.submitBtnTarget.textContent = "Adding..."

    try {
      const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
      const response = await fetch(`${this.baseUrlValue}/meal_plans/${planId}/meals`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify({
          meal_plan_day_id: dayId,
          meal: {
            recipe_id: this.recipeIdValue,
            meal_type: mealType,
            servings: servings
          }
        })
      })

      if (response.ok) {
        this.showMessage("Meal added successfully!", "success")
        setTimeout(() => this.close(), 1500)
      } else {
        const data = await response.json()
        this.showMessage(data.errors?.join(", ") || "Could not add meal.", "error")
      }
    } catch (e) {
      this.showMessage("Something went wrong. Please try again.", "error")
    } finally {
      this.submitBtnTarget.disabled = false
      this.submitBtnTarget.textContent = "Add Meal"
    }
  }

  showMessage(text, type) {
    this.messageTarget.textContent = text
    this.messageTarget.className = `mb-4 p-3 rounded-lg text-sm ${type === "success" ? "bg-green-50 text-green-700" : "bg-red-50 text-red-700"}`
    this.messageTarget.classList.remove("hidden")
  }

  hideMessage() {
    if (this.hasMessageTarget) {
      this.messageTarget.classList.add("hidden")
    }
  }

  reset() {
    if (this.hasPlanSelectTarget) this.planSelectTarget.value = ""
    if (this.hasStep2Target) this.step2Target.classList.add("hidden")
    if (this.hasServingsTarget) this.servingsTarget.value = "1"
    this.hideMessage()
  }
}
