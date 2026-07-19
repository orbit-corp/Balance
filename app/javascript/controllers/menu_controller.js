import { Controller } from "@hotwired/stimulus"

// Fixed-positioned dropdown so it is never clipped by table overflow containers.
export default class extends Controller {
  static targets = ["button", "menu"]

  toggle(event) {
    event.stopPropagation()
    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    const rect = this.buttonTarget.getBoundingClientRect()
    const menu = this.menuTarget
    menu.style.position = "fixed"
    menu.style.visibility = "hidden"
    menu.classList.remove("hidden")

    const mw = menu.offsetWidth
    const mh = menu.offsetHeight

    let top = rect.bottom + 4
    if (top + mh > window.innerHeight - 8) top = Math.max(8, rect.top - mh - 4)

    let left = rect.right - mw
    left = Math.max(8, Math.min(left, window.innerWidth - mw - 8))

    menu.style.top = `${top}px`
    menu.style.left = `${left}px`
    menu.style.visibility = ""

    this.outsideHandler = (event) => {
      if (!this.element.contains(event.target) && !this.menuTarget.contains(event.target)) this.close()
    }
    this.dismissHandler = () => this.close()
    document.addEventListener("click", this.outsideHandler)
    window.addEventListener("scroll", this.dismissHandler, true)
    window.addEventListener("resize", this.dismissHandler)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    if (this.outsideHandler) document.removeEventListener("click", this.outsideHandler)
    if (this.dismissHandler) {
      window.removeEventListener("scroll", this.dismissHandler, true)
      window.removeEventListener("resize", this.dismissHandler)
    }
  }

  disconnect() {
    this.close()
  }
}
