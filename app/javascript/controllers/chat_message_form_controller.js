import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "stubby:prompt-history"
const LIMIT = 50

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.cursor = null
    this.draft = ""
  }

  submitOnEnter(event) {
    if (event.shiftKey) return

    event.preventDefault()
    this.remember(this.inputTarget.value)
    this.element.requestSubmit()
  }

  previousPrompt(event) {
    const history = this.history
    if (!history.length || !this.caretOnFirstLine) return

    event.preventDefault()

    if (this.cursor === null) {
      this.draft = this.inputTarget.value
      this.cursor = history.length
    }

    if (this.cursor === 0) return
    this.cursor -= 1
    this.replaceWith(history[this.cursor])
  }

  nextPrompt(event) {
    if (this.cursor === null || !this.caretOnLastLine) return

    event.preventDefault()

    const history = this.history
    this.cursor += 1

    if (this.cursor >= history.length) {
      this.cursor = null
      this.replaceWith(this.draft)
      return
    }

    this.replaceWith(history[this.cursor])
  }

  replaceWith(value) {
    const input = this.inputTarget
    input.value = value
    input.setSelectionRange(value.length, value.length)
  }

  remember(prompt) {
    const value = prompt.trim()
    if (!value) return

    const history = this.history.filter((entry) => entry !== value)
    history.push(value)

    localStorage.setItem(STORAGE_KEY, JSON.stringify(history.slice(-LIMIT)))
    this.cursor = null
    this.draft = ""
  }

  get history() {
    try {
      const stored = JSON.parse(localStorage.getItem(STORAGE_KEY))
      return Array.isArray(stored) ? stored : []
    } catch {
      return []
    }
  }

  get caretOnFirstLine() {
    const input = this.inputTarget
    return input.selectionStart === input.selectionEnd && !input.value.slice(0, input.selectionStart).includes("\n")
  }

  get caretOnLastLine() {
    const input = this.inputTarget
    return input.selectionStart === input.selectionEnd && !input.value.slice(input.selectionEnd).includes("\n")
  }
}
