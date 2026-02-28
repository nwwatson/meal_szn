import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    currentStep: { type: Number, default: 1 },
    selectedDate: String,
    selectedDays: { type: Number, default: 7 },
    viewYear: Number,
    viewMonth: Number,
    todayIso: String,
    createUrl: String,
    generateUrl: String
  }

  static targets = [
    "step", "stepIndicator",
    "calendarGrid", "calendarTitle", "prevMonth",
    "durationButton", "customDaysInput", "customDaysLink",
    "selectedDateText", "summaryText",
    "nameField", "startDateField", "endDateField",
    "backButton", "nextButton", "navigationFooter"
  ]

  connect() {
    const today = new Date()
    this.viewYearValue = today.getFullYear()
    this.viewMonthValue = today.getMonth()
    this.todayIsoValue = this.formatDate(today)

    this.renderCalendar()
    this.updateStepVisibility()
  }

  // === Calendar rendering ===

  renderCalendar() {
    const year = this.viewYearValue
    const month = this.viewMonthValue
    const firstDay = new Date(year, month, 1)
    const lastDay = new Date(year, month + 1, 0)
    const startPad = firstDay.getDay() // 0=Sun

    const monthNames = ["January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"]
    this.calendarTitleTarget.textContent = `${monthNames[month]} ${year}`

    // Hide prev arrow if viewing current month
    const now = new Date()
    if (year === now.getFullYear() && month === now.getMonth()) {
      this.prevMonthTarget.classList.add("invisible")
    } else {
      this.prevMonthTarget.classList.remove("invisible")
    }

    let html = ""

    // Blank padding for first row
    for (let i = 0; i < startPad; i++) {
      html += `<div></div>`
    }

    for (let d = 1; d <= lastDay.getDate(); d++) {
      const date = new Date(year, month, d)
      const iso = this.formatDate(date)
      const isPast = iso < this.todayIsoValue
      const isToday = iso === this.todayIsoValue
      const isSelected = iso === this.selectedDateValue

      let classes = "w-10 h-10 rounded-full text-sm font-medium flex items-center justify-center mx-auto transition-all duration-150 "

      if (isSelected) {
        classes += "bg-primary-600 text-white shadow-md scale-110"
      } else if (isPast) {
        classes += "text-warm-300 cursor-not-allowed"
      } else if (isToday) {
        classes += "ring-2 ring-primary-300 text-primary-700 hover:bg-primary-100 cursor-pointer"
      } else {
        classes += "text-warm-700 hover:bg-primary-100 cursor-pointer"
      }

      if (isPast && !isSelected) {
        html += `<div><div class="${classes}">${d}</div></div>`
      } else {
        html += `<div><button type="button" class="${classes}" data-action="meal-plan-wizard#selectDate" data-date="${iso}">${d}</button></div>`
      }
    }

    this.calendarGridTarget.innerHTML = html
  }

  prevMonthAction() {
    if (this.viewMonthValue === 0) {
      this.viewMonthValue = 11
      this.viewYearValue--
    } else {
      this.viewMonthValue--
    }
    this.renderCalendar()
  }

  nextMonthAction() {
    if (this.viewMonthValue === 11) {
      this.viewMonthValue = 0
      this.viewYearValue++
    } else {
      this.viewMonthValue++
    }
    this.renderCalendar()
  }

  selectDate(event) {
    event.preventDefault()
    this.selectedDateValue = event.currentTarget.dataset.date
    this.renderCalendar()

    // Auto-advance to step 2 after brief delay
    setTimeout(() => {
      this.currentStepValue = 2
      this.updateStepVisibility()
      this.updateDurationStep()
    }, 200)
  }

  // === Duration selection ===

  updateDurationStep() {
    const formatted = this.formatDisplayDate(this.selectedDateValue)
    if (this.hasSelectedDateTextTarget) {
      this.selectedDateTextTarget.textContent = formatted
    }
    this.highlightDurationButtons()
    this.computeEndDate()
  }

  selectDuration(event) {
    event.preventDefault()
    const days = parseInt(event.currentTarget.dataset.days)
    this.selectedDaysValue = days
    this.highlightDurationButtons()
    this.computeEndDate()

    // Hide custom input if showing
    if (this.hasCustomDaysInputTarget) {
      this.customDaysInputTarget.classList.add("hidden")
      this.customDaysLinkTarget.classList.remove("hidden")
    }
  }

  highlightDurationButtons() {
    this.durationButtonTargets.forEach(btn => {
      const days = parseInt(btn.dataset.days)
      if (days === this.selectedDaysValue) {
        btn.classList.remove("border-warm-200", "bg-white", "text-warm-700")
        btn.classList.add("border-primary-500", "bg-primary-50", "text-primary-700", "ring-2", "ring-primary-200", "scale-105")
      } else {
        btn.classList.add("border-warm-200", "bg-white", "text-warm-700")
        btn.classList.remove("border-primary-500", "bg-primary-50", "text-primary-700", "ring-2", "ring-primary-200", "scale-105")
      }
    })
  }

  showCustomDays(event) {
    event.preventDefault()
    this.customDaysLinkTarget.classList.add("hidden")
    this.customDaysInputTarget.classList.remove("hidden")
    this.customDaysInputTarget.querySelector("input").focus()
  }

  setCustomDays(event) {
    let val = parseInt(event.currentTarget.value)
    if (isNaN(val) || val < 1) val = 1
    if (val > 30) val = 30
    this.selectedDaysValue = val

    // Deselect preset buttons
    this.durationButtonTargets.forEach(btn => {
      btn.classList.add("border-warm-200", "bg-white", "text-warm-700")
      btn.classList.remove("border-primary-500", "bg-primary-50", "text-primary-700", "ring-2", "ring-primary-200", "scale-105")
    })

    this.computeEndDate()
  }

  computeEndDate() {
    if (!this.selectedDateValue) return
    const start = new Date(this.selectedDateValue + "T00:00:00")
    const end = new Date(start)
    end.setDate(end.getDate() + this.selectedDaysValue - 1)
    this.endDateIso = this.formatDate(end)

    if (this.hasSummaryTextTarget) {
      const startDisplay = this.formatDisplayDate(this.selectedDateValue)
      const endDisplay = this.formatDisplayDate(this.endDateIso)
      this.summaryTextTarget.textContent = `${startDisplay} \u2013 ${endDisplay} (${this.selectedDaysValue} days)`
    }
  }

  // === Step navigation ===

  nextStep() {
    if (this.currentStepValue < 3) {
      this.currentStepValue++
      this.updateStepVisibility()
      if (this.currentStepValue === 2) this.updateDurationStep()
      if (this.currentStepValue === 3) this.computeEndDate()
    }
  }

  prevStep() {
    if (this.currentStepValue > 1) {
      this.currentStepValue--
      this.updateStepVisibility()
    }
  }

  updateStepVisibility() {
    const step = this.currentStepValue

    this.stepTargets.forEach((el, idx) => {
      if (idx + 1 === step) {
        el.classList.remove("hidden")
      } else {
        el.classList.add("hidden")
      }
    })

    // Update step indicators
    this.stepIndicatorTargets.forEach((el, idx) => {
      const stepNum = idx + 1
      const circle = el.querySelector("[data-circle]")
      const label = el.querySelector("[data-label]")
      const line = el.querySelector("[data-line]")

      if (stepNum < step) {
        // Completed
        if (circle) {
          circle.className = "w-8 h-8 rounded-full flex items-center justify-center bg-primary-600 text-white text-sm font-bold"
          circle.innerHTML = '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7"/></svg>'
        }
        if (label) label.className = "text-xs font-medium text-primary-600 mt-1"
        if (line) line.className = "h-0.5 bg-primary-600 flex-1"
      } else if (stepNum === step) {
        // Current
        if (circle) {
          circle.className = "w-8 h-8 rounded-full flex items-center justify-center bg-primary-600 text-white text-sm font-bold"
          circle.textContent = stepNum
        }
        if (label) label.className = "text-xs font-medium text-primary-700 mt-1"
        if (line) line.className = "h-0.5 bg-warm-200 flex-1"
      } else {
        // Future
        if (circle) {
          circle.className = "w-8 h-8 rounded-full flex items-center justify-center bg-warm-100 text-warm-400 text-sm font-medium"
          circle.textContent = stepNum
        }
        if (label) label.className = "text-xs font-medium text-warm-400 mt-1"
        if (line) line.className = "h-0.5 bg-warm-200 flex-1"
      }
    })

    // Navigation footer: show on steps 1-2, hide on 3
    if (this.hasNavigationFooterTarget) {
      this.navigationFooterTarget.classList.toggle("hidden", step === 3)
    }

    // Back button visibility
    if (this.hasBackButtonTarget) {
      this.backButtonTarget.classList.toggle("invisible", step === 1)
    }

    // Next/continue button
    if (this.hasNextButtonTarget) {
      this.nextButtonTarget.disabled = (step === 1 && !this.selectedDateValue)
    }
  }

  // === Form submission ===

  skipAi(event) {
    event.preventDefault()
    this.populateHiddenFields()

    const form = this.element.querySelector("form")
    form.action = this.createUrlValue
    form.requestSubmit()
  }

  beforeSubmit() {
    this.populateHiddenFields()
  }

  populateHiddenFields() {
    if (!this.selectedDateValue) return

    const start = new Date(this.selectedDateValue + "T00:00:00")
    const end = new Date(start)
    end.setDate(end.getDate() + this.selectedDaysValue - 1)

    const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    const name = `Week of ${monthNames[start.getMonth()]} ${start.getDate()}, ${start.getFullYear()}`

    this.nameFieldTarget.value = name
    this.startDateFieldTarget.value = this.selectedDateValue
    this.endDateFieldTarget.value = this.formatDate(end)
  }

  // === Helpers ===

  formatDate(date) {
    const y = date.getFullYear()
    const m = String(date.getMonth() + 1).padStart(2, "0")
    const d = String(date.getDate()).padStart(2, "0")
    return `${y}-${m}-${d}`
  }

  formatDisplayDate(iso) {
    const date = new Date(iso + "T00:00:00")
    const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    const dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    return `${dayNames[date.getDay()]}, ${monthNames[date.getMonth()]} ${date.getDate()}`
  }
}
