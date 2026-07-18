import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["kindInput", "categorySelect", "customerField"]

  connect() {
    this.toggleKind()
  }

  toggleKind() {
    const kind = this.kindInputTargets.find((input) => input.checked)?.value
    if (!kind) return

    for (const optgroup of this.categorySelectTarget.querySelectorAll("optgroup")) {
      const matches = optgroup.label === (kind === "income" ? "Sales" : "Expense")
      optgroup.hidden = !matches
      for (const option of optgroup.querySelectorAll("option")) {
        option.disabled = !matches
      }
    }

    const selected = this.categorySelectTarget.querySelector("option:checked")
    if (selected?.disabled) {
      const firstEnabled = this.categorySelectTarget.querySelector("option:not(:disabled)")
      if (firstEnabled) firstEnabled.selected = true
    }

    this.customerFieldTarget.classList.toggle("hidden", kind !== "income")
  }
}
