import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = { prompts: Array }

  connect() {
    this.index = this.promptsValue.length - 1
    this.deleting = true
    this.schedule(500)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  schedule(delay) {
    this.timeout = setTimeout(() => this.animate(), delay)
  }

  animate() {
    if (this.inputTarget.value.length > 0) return this.schedule(250)

    const prompt = this.promptsValue[this.index]
    const placeholder = this.inputTarget.placeholder

    if (this.deleting) {
      this.inputTarget.placeholder = placeholder.slice(0, -1)
      if (this.inputTarget.placeholder.length === 0) {
        this.deleting = false
        this.index = (this.index + 1) % this.promptsValue.length
        return this.schedule(300)
      }
      return this.schedule(18)
    }

    this.inputTarget.placeholder = prompt.slice(0, placeholder.length + 1)
    if (this.inputTarget.placeholder === prompt) {
      this.deleting = true
      return this.schedule(1800)
    }

    this.schedule(28)
  }
}
