import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["detail", "icon"]

  toggle() {
    this.detailTarget.hidden = !this.detailTarget.hidden
    this.iconTarget.classList.toggle("rotate-90")
    this.element.querySelector("button")?.setAttribute("aria-expanded", String(!this.detailTarget.hidden))
  }
}
