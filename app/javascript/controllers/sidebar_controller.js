import { Controller } from "@hotwired/stimulus"

const COLLAPSED_KEY = "balance:sidebar-collapsed"

export default class extends Controller {
  static targets = ["panel", "expanded", "collapsed", "collapseIcon", "navLink"]

  connect() {
    this.setCollapsed(localStorage.getItem(COLLAPSED_KEY) === "true")
    document.addEventListener("turbo:morph", this.restore)
  }

  disconnect() {
    document.removeEventListener("turbo:morph", this.restore)
  }

  restore = () => this.setCollapsed(localStorage.getItem(COLLAPSED_KEY) === "true")

  collapse() {
    this.setCollapsed(!this.collapsed, true)
  }

  setCollapsed(collapsed, persist = false) {
    this.collapsed = collapsed
    if (persist) localStorage.setItem(COLLAPSED_KEY, collapsed)

    this.panelTarget.classList.toggle("w-64", !collapsed)
    this.panelTarget.classList.toggle("w-16", collapsed)
    this.expandedTargets.forEach((element) => { element.hidden = collapsed })
    this.collapsedTargets.forEach((element) => { element.hidden = !collapsed })
    this.collapseIconTarget.classList.toggle("rotate-180", !collapsed)
    this.navLinkTargets.forEach((element) => {
      element.classList.toggle("justify-center", collapsed)
      element.classList.toggle("px-2", collapsed)
      element.classList.toggle("px-3", !collapsed)
    })
  }
}
