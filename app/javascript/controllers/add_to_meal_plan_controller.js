import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "mealszn_last_meal_plan_id"
const MEAL_TYPES = [
  { key: "breakfast", label: "Breakfast", icon: "M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707" },
  { key: "lunch", label: "Lunch", icon: "M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" },
  { key: "dinner", label: "Dinner", icon: "M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 100 4 2 2 0 000-4z" },
  { key: "snack", label: "Snack", icon: "M13 10V3L4 14h7v7l9-11h-7z" }
]

export default class extends Controller {
  static targets = ["container", "backdrop", "dialog", "step1", "step2", "step3",
                     "message", "morePlans", "backBtn", "title", "dayButtons",
                     "mealButtons", "lastUsedBadge"]
  static values = { recipeId: String, baseUrl: String }

  connect() {
    this.currentStep = 1
    this.selectedPlan = null
    this.selectedDay = null
    this.markLastUsedPlan()
  }

  markLastUsedPlan() {
    const lastId = localStorage.getItem(STORAGE_KEY)
    if (!lastId) return

    this.lastUsedBadgeTargets.forEach(badge => {
      if (badge.dataset.planId === lastId) {
        badge.classList.remove("hidden")
        // Move this plan's button to the top
        const btn = badge.closest("button.plan-btn")
        if (btn && btn.parentElement) {
          btn.parentElement.prepend(btn)
        }
      }
    })
  }

  open() {
    this.containerTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"
    this.hideMessage()
    this.goToStep(1)

    requestAnimationFrame(() => {
      this.backdropTarget.classList.remove("opacity-0")
      this.backdropTarget.classList.add("opacity-100")
      this.dialogTarget.classList.remove("opacity-0", "scale-95")
      this.dialogTarget.classList.add("opacity-100", "scale-100")
    })
  }

  close() {
    this.backdropTarget.classList.remove("opacity-100")
    this.backdropTarget.classList.add("opacity-0")
    this.dialogTarget.classList.remove("opacity-100", "scale-100")
    this.dialogTarget.classList.add("opacity-0", "scale-95")

    const onEnd = () => {
      this.containerTarget.classList.add("hidden")
      document.body.style.overflow = ""
      this.goToStep(1)
      this.hideMessage()
    }

    this.dialogTarget.addEventListener("transitionend", onEnd, { once: true })
    setTimeout(onEnd, 250)
  }

  goToStep(step) {
    this.currentStep = step
    this.step1Target.classList.toggle("hidden", step !== 1)
    this.step2Target.classList.toggle("hidden", step !== 2)
    this.step3Target.classList.toggle("hidden", step !== 3)
    this.backBtnTarget.classList.toggle("hidden", step === 1)

    const titles = { 1: "Add to Meal Plan", 2: this.selectedPlan?.name || "Select Day", 3: this.selectedDay?.label?.split(" — ")[1] || "Select Meal" }
    this.titleTarget.textContent = titles[step]
  }

  back() {
    if (this.currentStep > 1) {
      this.goToStep(this.currentStep - 1)
    }
  }

  selectPlan(event) {
    const btn = event.currentTarget
    this.selectedPlan = JSON.parse(btn.dataset.planJson)

    localStorage.setItem(STORAGE_KEY, this.selectedPlan.id)

    // Build day buttons
    this.dayButtonsTarget.innerHTML = this.selectedPlan.days.map(day => `
      <button type="button"
        data-action="add-to-meal-plan#selectDay"
        data-day-json='${JSON.stringify(day).replace(/'/g, "&#39;")}'
        class="w-full text-left px-4 py-3 rounded-xl border-2 border-warm-200 hover:border-primary-400 hover:bg-primary-50/50 transition-all group">
        <div class="flex items-center justify-between">
          <span class="font-semibold text-warm-800 group-hover:text-primary-700">${day.label}</span>
          <svg class="w-5 h-5 text-warm-300 group-hover:text-primary-500 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>
        </div>
      </button>
    `).join("")

    this.goToStep(2)
  }

  selectDay(event) {
    const btn = event.currentTarget
    this.selectedDay = JSON.parse(btn.dataset.dayJson)

    // Build meal type buttons with "Replace" context
    this.mealButtonsTarget.innerHTML = MEAL_TYPES.map(({ key, label, icon }) => {
      const existing = this.selectedDay.meals[key]
      const replaceText = existing ? `<span class="block text-xs text-warm-400 mt-0.5 truncate">Replace: ${this.escapeHtml(existing.recipe_title || "Unknown")}</span>` : ""
      const existingId = existing ? existing.id : ""

      return `
        <button type="button"
          data-action="add-to-meal-plan#selectMealType"
          data-meal-type="${key}"
          data-existing-meal-id="${existingId}"
          class="w-full text-left px-4 py-3 rounded-xl border-2 ${existing ? "border-accent-200 bg-accent-50/30" : "border-warm-200"} hover:border-primary-400 hover:bg-primary-50/50 transition-all group">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-3">
              <div class="w-9 h-9 rounded-lg ${existing ? "bg-accent-100" : "bg-warm-100"} flex items-center justify-center group-hover:bg-primary-100 transition-colors">
                <svg class="w-5 h-5 ${existing ? "text-accent-500" : "text-warm-400"} group-hover:text-primary-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="${icon}"/></svg>
              </div>
              <div>
                <span class="font-semibold text-warm-800 group-hover:text-primary-700">${label}</span>
                ${replaceText}
              </div>
            </div>
            <svg class="w-5 h-5 text-warm-300 group-hover:text-primary-500 transition-colors flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="${existing ? "M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" : "M12 4v16m8-8H4"}"/></svg>
          </div>
        </button>
      `
    }).join("")

    this.goToStep(3)
  }

  async selectMealType(event) {
    const btn = event.currentTarget
    const mealType = btn.dataset.mealType
    const existingMealId = btn.dataset.existingMealId
    const planId = this.selectedPlan.id
    const dayId = this.selectedDay.id

    // Disable all meal buttons
    this.mealButtonsTarget.querySelectorAll("button").forEach(b => {
      b.disabled = true
      b.classList.add("opacity-50")
    })
    btn.classList.remove("opacity-50")
    btn.classList.add("opacity-75")

    try {
      const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
      const headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": csrfToken
      }

      // If replacing, delete existing meal first
      if (existingMealId) {
        const deleteRes = await fetch(`${this.baseUrlValue}/meal_plans/${planId}/meals/${existingMealId}`, {
          method: "DELETE",
          headers
        })
        if (!deleteRes.ok) {
          throw new Error("Failed to remove existing meal")
        }
      }

      // Create new meal
      const response = await fetch(`${this.baseUrlValue}/meal_plans/${planId}/meals`, {
        method: "POST",
        headers,
        body: JSON.stringify({
          meal_plan_day_id: dayId,
          meal: {
            recipe_id: this.recipeIdValue,
            meal_type: mealType,
            servings: 1
          }
        })
      })

      if (response.ok) {
        this.showMessage(existingMealId ? "Meal replaced!" : "Meal added!", "success")
        setTimeout(() => this.close(), 1200)
      } else {
        const data = await response.json()
        this.showMessage(data.errors?.join(", ") || "Could not add meal.", "error")
      }
    } catch (e) {
      this.showMessage(e.message || "Something went wrong. Please try again.", "error")
    } finally {
      this.mealButtonsTarget.querySelectorAll("button").forEach(b => {
        b.disabled = false
        b.classList.remove("opacity-50", "opacity-75")
      })
    }
  }

  showMore() {
    // Reveal hidden plan buttons
    this.step1Target.querySelectorAll("button.plan-btn.hidden").forEach(btn => {
      btn.classList.remove("hidden")
    })
    if (this.hasMorePlansTarget) {
      this.morePlansTarget.classList.add("hidden")
    }
  }

  showMessage(text, type) {
    this.messageTarget.textContent = text
    this.messageTarget.className = `mx-5 mt-4 p-3 rounded-lg text-sm ${type === "success" ? "bg-green-50 text-green-700 border border-green-200" : "bg-red-50 text-red-700 border border-red-200"}`
    this.messageTarget.classList.remove("hidden")
  }

  hideMessage() {
    if (this.hasMessageTarget) {
      this.messageTarget.classList.add("hidden")
    }
  }

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
