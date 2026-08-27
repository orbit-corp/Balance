import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["defaultIcon", "doneIcon"]
  static values = { value: String }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.valueValue)
    } catch {
      return
    }

    this.defaultIconTarget.hidden = true
    this.doneIconTarget.hidden = false
    clearTimeout(this.resetTimeout)
    this.resetTimeout = setTimeout(() => this.reset(), 1600)
  }

  disconnect() {
    clearTimeout(this.resetTimeout)
  }

  reset() {
    this.defaultIconTarget.hidden = false
    this.doneIconTarget.hidden = true
  }
}
