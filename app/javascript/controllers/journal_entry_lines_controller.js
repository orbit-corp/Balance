import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["lines", "template", "debit", "credit", "debitTotal", "creditTotal", "difference"]

  addLine() {
    const index = Date.now()
    const html = this.templateTarget.innerHTML.replaceAll("__INDEX__", index)
    this.linesTarget.insertAdjacentHTML("beforeend", html)
    this.recalculate()
  }

  removeLine(event) {
    const row = event.target.closest("[data-journal-entry-lines-target='row']")
    const destroyInput = row.querySelector("input[name*='_destroy']")

    if (destroyInput) {
      destroyInput.value = "1"
      row.hidden = true
    } else {
      row.remove()
    }

    this.recalculate()
  }

  recalculate() {
    const sum = (targets) => targets.reduce((total, input) => total + (parseFloat(input.value) || 0), 0)

    const debitTotal = sum(this.debitTargets.filter((input) => !input.closest("[hidden]")))
    const creditTotal = sum(this.creditTargets.filter((input) => !input.closest("[hidden]")))

    this.debitTotalTarget.textContent = debitTotal.toFixed(2)
    this.creditTotalTarget.textContent = creditTotal.toFixed(2)
    this.differenceTarget.textContent = (debitTotal - creditTotal).toFixed(2)
  }
}
