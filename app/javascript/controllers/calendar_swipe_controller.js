import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dayPanel", "dayTab"]
  static values = { currentIndex: { type: Number, default: 0 } }

  touchStart(event) {
    this.startX = event.touches[0].clientX
  }

  touchEnd(event) {
    if (!this.startX) return

    const endX = event.changedTouches[0].clientX
    const diff = this.startX - endX

    if (Math.abs(diff) > 50) {
      if (diff > 0) {
        this.next()
      } else {
        this.prev()
      }
    }

    this.startX = null
  }

  selectDay(event) {
    const index = parseInt(event.currentTarget.dataset.dayIndex, 10)
    this.showDay(index)
  }

  next() {
    if (this.currentIndexValue < this.dayPanelTargets.length - 1) {
      this.showDay(this.currentIndexValue + 1)
    }
  }

  prev() {
    if (this.currentIndexValue > 0) {
      this.showDay(this.currentIndexValue - 1)
    }
  }

  showDay(index) {
    this.currentIndexValue = index

    this.dayPanelTargets.forEach((panel, i) => {
      panel.classList.toggle("hidden", i !== index)
    })

    this.dayTabTargets.forEach((tab, i) => {
      if (i === index) {
        tab.classList.add("bg-primary-600", "text-white")
        tab.classList.remove("bg-warm-100", "text-warm-600")
      } else {
        tab.classList.remove("bg-primary-600", "text-white")
        tab.classList.add("bg-warm-100", "text-warm-600")
      }
    })
  }
}
