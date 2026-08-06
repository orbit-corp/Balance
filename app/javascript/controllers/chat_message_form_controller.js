import { Controller } from "@hotwired/stimulus"

// Enter submits the message; Shift+Enter inserts a newline as usual.
export default class extends Controller {
  static targets = ["input"]

  submitOnEnter(event) {
    if (event.shiftKey) return

    event.preventDefault()
    this.element.requestSubmit()
  }
}
