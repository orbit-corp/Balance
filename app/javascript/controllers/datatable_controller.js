import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "tab", "selectAll", "rowCheck", "count"]

  connect() {
    this.updateCount()
  }

  filter(event) {
    const kind = event.currentTarget.dataset.kind

    for (const tab of this.tabTargets) {
      const active = tab.dataset.kind === kind
      tab.classList.toggle("bg-gradient-to-b", active)
      tab.classList.toggle("from-white", active)
      tab.classList.toggle("to-neutral-50", active)
      tab.classList.toggle("shadow-sm", active)
      tab.classList.toggle("text-neutral-900", active)
      tab.classList.toggle("text-neutral-500", !active)
    }

    for (const row of this.rowTargets) {
      row.classList.toggle("hidden", kind !== "all" && row.dataset.kind !== kind)
    }

    if (this.hasSelectAllTarget) this.selectAllTarget.checked = false
    for (const check of this.rowCheckTargets) check.checked = false
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
