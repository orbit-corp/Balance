import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "selectAll", "rowCheck", "count"]

  connect() {
    this.updateCount()
  }

  toggleAll() {
    for (const check of this.rowCheckTargets) {
      if (!check.closest("tr").classList.contains("hidden")) check.checked = this.selectAllTarget.checked
    }
    this.updateCount()
  }

  rowToggle() {
    this.updateCount()
  }

  updateCount() {
    const visible = this.rowCheckTargets.filter((c) => !c.closest("tr").classList.contains("hidden"))
    const selected = visible.filter((c) => c.checked).length
    if (this.hasCountTarget) {
      this.countTarget.textContent = `${selected} of ${visible.length} row(s) selected.`
    }
  }
}
