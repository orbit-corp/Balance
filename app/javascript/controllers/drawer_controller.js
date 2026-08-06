import { Controller } from "@hotwired/stimulus"

// Same open/close lifecycle as modal_controller, but slides in from the right
// instead of fading/scaling in place.
export default class extends Controller {
  static targets = ["backdrop", "panel"]
  static values = { duration: { type: Number, default: 200 } }

  connect() {
    document.body.classList.add("overflow-hidden")
    requestAnimationFrame(() => this.show())
    this.element.focus()
  }

  disconnect() {
    document.body.classList.remove("overflow-hidden")
    clearTimeout(this.closeTimeout)
  }

  show() {
    this.backdropTarget.classList.replace("opacity-0", "opacity-100")
    this.panelTarget.classList.remove("translate-x-full")
  }

  close(event) {
    event?.preventDefault()
    if (this.closing) return
    this.closing = true

    this.backdropTarget.classList.replace("opacity-100", "opacity-0")
    this.panelTarget.classList.add("translate-x-full")

    this.closeTimeout = setTimeout(() => {
      const frame = document.getElementById("modal")
      if (frame) frame.innerHTML = ""
    }, this.reducedMotion ? 0 : this.durationValue)
  }

  clickOutside(event) {
    if (event.target === this.backdropTarget) this.close(event)
  }

  keydown(event) {
    if (event.key === "Escape") this.close(event)
  }

  get reducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }
}
