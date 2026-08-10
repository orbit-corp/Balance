import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { duration: { type: Number, default: 4000 } }

  connect() {
    this.element.classList.add("-translate-y-full", "opacity-0", "transition", "duration-300", "ease-out")

    requestAnimationFrame(() => {
      this.element.classList.remove("-translate-y-full", "opacity-0")
    })

    this.timeout = setTimeout(() => this.dismiss(), this.durationValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
    clearTimeout(this.removeTimeout)
  }

  dismiss() {
    this.element.classList.add("-translate-y-full", "opacity-0")
    this.removeTimeout = setTimeout(() => this.element.remove(), 300)
  }
}
