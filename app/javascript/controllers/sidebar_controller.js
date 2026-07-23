import { Controller } from "@hotwired/stimulus"

const COLLAPSED_KEY = "stubby:sidebar-collapsed"

export default class extends Controller {
  static targets = ["panel", "backdrop"]

  connect() {
    if (localStorage.getItem(COLLAPSED_KEY) === "true") {
      this.panelTarget.classList.add("md:hidden")
    }
  }

  toggle() {
    this.panelTarget.classList.toggle("-translate-x-full")
    this.backdropTarget.classList.toggle("hidden")
  }

  collapse() {
    const collapsed = this.panelTarget.classList.toggle("md:hidden")
    localStorage.setItem(COLLAPSED_KEY, collapsed)
  }
}
