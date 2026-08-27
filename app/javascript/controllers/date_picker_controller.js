import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

export default class extends Controller {
  connect() {
    this.picker = flatpickr(this.element, {
      altInput: true,
      altFormat: "M j, Y",
      dateFormat: "Y-m-d",
      defaultDate: this.element.value || "today",
      maxDate: "today",
      allowInput: true
    })
  }

  disconnect() {
    this.picker?.destroy()
  }
}
