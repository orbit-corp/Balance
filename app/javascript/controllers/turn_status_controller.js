import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = { url: String }

  connect() {
    // this.timer = window.setInterval(() => this.refresh(), 2000)
  }

  disconnect() {
    window.clearInterval(this.timer)
  }

  async refresh() {
    const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
    if (!response.ok) return

    const turn = await response.json()
    if (turn.terminal) Turbo.visit(window.location.href, { action: "replace" })
  }
}
