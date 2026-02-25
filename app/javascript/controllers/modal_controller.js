import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "backdrop", "dialog", "participantsContainer", "participantsBackdrop", "participantsDialog"]

  open(event) {
    const variant = this.variantFrom(event)
    const container = this.containerFor(variant)
    const backdrop = this.backdropFor(variant)
    const dialog = this.dialogFor(variant)

    container.classList.remove("hidden")
    document.body.style.overflow = "hidden"

    // Trigger enter animation on next frame
    requestAnimationFrame(() => {
      if (backdrop) {
        backdrop.classList.remove("opacity-0")
        backdrop.classList.add("opacity-100")
      }
      if (dialog) {
        dialog.classList.remove("opacity-0", "scale-95")
        dialog.classList.add("opacity-100", "scale-100")
      }
    })
  }

  close(event) {
    const variant = this.variantFrom(event)
    const container = this.containerFor(variant)
    const backdrop = this.backdropFor(variant)
    const dialog = this.dialogFor(variant)

    // Animate out
    if (backdrop) {
      backdrop.classList.remove("opacity-100")
      backdrop.classList.add("opacity-0")
    }
    if (dialog) {
      dialog.classList.remove("opacity-100", "scale-100")
      dialog.classList.add("opacity-0", "scale-95")
    }

    // Hide after transition
    const onEnd = () => {
      container.classList.add("hidden")
      document.body.style.overflow = ""
    }

    if (dialog) {
      dialog.addEventListener("transitionend", onEnd, { once: true })
      // Fallback
      setTimeout(onEnd, 250)
    } else {
      onEnd()
    }
  }

  // Determine which modal variant (default or participants) based on the trigger
  variantFrom(event) {
    const target = event?.currentTarget?.dataset?.modalTarget || event?.params?.variant
    if (target === "participantsContainer") return "participants"
    return "default"
  }

  containerFor(variant) {
    return variant === "participants" && this.hasParticipantsContainerTarget
      ? this.participantsContainerTarget
      : this.containerTarget
  }

  backdropFor(variant) {
    if (variant === "participants" && this.hasParticipantsBackdropTarget) return this.participantsBackdropTarget
    return this.hasBackdropTarget ? this.backdropTarget : null
  }

  dialogFor(variant) {
    if (variant === "participants" && this.hasParticipantsDialogTarget) return this.participantsDialogTarget
    return this.hasDialogTarget ? this.dialogTarget : null
  }
}
