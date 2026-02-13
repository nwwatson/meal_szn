import { Controller } from "@hotwired/stimulus"

const DIETS = {
  "Standard / USDA Guidelines": { fat: [20, 35], protein: [10, 35], carbs: [45, 65] },
  "Ketogenic (Keto)": { fat: [70, 75], protein: [20, 25], carbs: [5, 10] },
  "Low-Carb (non-keto)": { fat: [30, 40], protein: [30, 40], carbs: [20, 30] },
  "Paleo": { fat: [30, 40], protein: [25, 35], carbs: [30, 40] },
  "Zone Diet": { fat: [30, 30], protein: [30, 30], carbs: [40, 40] },
  "Mediterranean": { fat: [30, 40], protein: [15, 20], carbs: [40, 50] },
  "High-Protein / Bodybuilding": { fat: [20, 30], protein: [40, 50], carbs: [30, 40] },
  "Carnivore": { fat: [60, 80], protein: [20, 40], carbs: [0, 0] },
  "Vegan (whole-food)": { fat: [20, 30], protein: [15, 20], carbs: [50, 60] },
  "If It Fits Your Macros (IIFYM)": null
}

export default class extends Controller {
  static targets = ["dietSelect", "caloriesInput", "preview", "fatValue", "proteinValue", "carbsValue"]

  update() {
    const dietName = this.dietSelectTarget.value
    const calories = parseInt(this.caloriesInputTarget.value)

    if (!dietName || !calories || calories <= 0) {
      this.previewTarget.classList.add("hidden")
      return
    }

    const diet = DIETS[dietName]
    if (!diet) {
      this.previewTarget.classList.add("hidden")
      return
    }

    const fatMid = (diet.fat[0] + diet.fat[1]) / 2
    const proteinMid = (diet.protein[0] + diet.protein[1]) / 2
    const carbsMid = (diet.carbs[0] + diet.carbs[1]) / 2

    const fatG = (calories * fatMid / 100 / 9).toFixed(1)
    const proteinG = (calories * proteinMid / 100 / 4).toFixed(1)
    const carbsG = (calories * carbsMid / 100 / 4).toFixed(1)

    this.fatValueTarget.textContent = `${fatG}g`
    this.proteinValueTarget.textContent = `${proteinG}g`
    this.carbsValueTarget.textContent = `${carbsG}g`

    this.previewTarget.classList.remove("hidden")
    this.previewTarget.innerHTML = `
      <div class="bg-gray-50 rounded-lg p-4">
        <h4 class="text-sm font-medium text-gray-700 mb-2">Daily Macro Targets</h4>
        <div class="grid grid-cols-3 gap-4 text-sm">
          <div><span class="text-gray-500">Fat:</span> <span class="font-medium">${fatG}g</span></div>
          <div><span class="text-gray-500">Protein:</span> <span class="font-medium">${proteinG}g</span></div>
          <div><span class="text-gray-500">Carbs:</span> <span class="font-medium">${carbsG}g</span></div>
        </div>
      </div>
    `
  }
}
