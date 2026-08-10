import { Controller } from "@hotwired/stimulus"

const MARGIN = 8

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

    menu.style.top = `${rect.bottom + 4}px`
    menu.style.left = `${rect.right - menu.offsetWidth}px`
    this.nudgeIntoView()

    menu.style.visibility = ""

    this.outsideHandler = (event) => {
      if (!this.element.contains(event.target) && !this.menuTarget.contains(event.target)) this.close()
    }
    this.dismissHandler = () => this.close()
    document.addEventListener("click", this.outsideHandler)
    window.addEventListener("scroll", this.dismissHandler, true)
    window.addEventListener("resize", this.dismissHandler)
  }

  nudgeIntoView() {
    const menu = this.menuTarget
    const box = menu.getBoundingClientRect()

    const overflowRight = box.right - (window.innerWidth - MARGIN)
    const overflowLeft = MARGIN - box.left
    const shiftX = overflowRight > 0 ? -overflowRight : Math.max(0, overflowLeft)
    if (shiftX) menu.style.left = `${parseFloat(menu.style.left) + shiftX}px`

    const overflowBottom = box.bottom - (window.innerHeight - MARGIN)
    if (overflowBottom > 0) {
      const flipped = parseFloat(menu.style.top) - box.height - this.buttonTarget.getBoundingClientRect().height - 8
      menu.style.top = `${Math.max(MARGIN, flipped)}px`
    }
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
