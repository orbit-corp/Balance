import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["accountType", "baseType", "detailType"]
  static values = { taxonomy: Object, accountType: String, detailType: String }

  connect() {
    this.refreshDetailTypes(this.accountTypeValue, this.detailTypeValue)
  }

  accountTypeChanged() {
    this.refreshDetailTypes(this.accountTypeTarget.value)
  }

  refreshDetailTypes(accountType, preselect) {
    const entry = this.taxonomyValue[accountType] || {}

    if (this.hasBaseTypeTarget && entry.category) {
      this.baseTypeTarget.value = entry.category.toLowerCase()
    }

    this.fillSelect(this.detailTypeTarget, entry.detail_types || [], "Select detail type", preselect)
  }

  fillSelect(select, values, promptText, preselect) {
    const options = [`<option value="">${promptText}</option>`]

    for (const value of values) {
      const selected = value === preselect ? " selected" : ""
      options.push(`<option value="${value}"${selected}>${value}</option>`)
    }

    select.innerHTML = options.join("")
  }
}