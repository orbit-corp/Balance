import { Controller } from "@hotwired/stimulus"

// Copies data-copy-value to the clipboard and flashes the trigger's label.
export default class extends Controller {
  static values = { value: String, label: String, doneLabel: { type: String, default: "Copied" } }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.valueValue)
    } catch {
      return
    }

    const original = this.labelValue || this.element.textContent
    this.element.textContent = this.doneLabelValue
    clearTimeout(this.resetTimeout)
    this.resetTimeout = setTimeout(() => { this.element.textContent = original }, 1600)
  }
}
