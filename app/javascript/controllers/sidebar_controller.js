import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "backdrop"]

  toggle() {
    this.panelTarget.classList.toggle("-translate-x-full")
    this.backdropTarget.classList.toggle("hidden")
  }
}
