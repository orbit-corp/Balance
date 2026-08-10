import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["baseType", "accountType", "detailType"]
  static values = { taxonomy: Object, accountType: String, detailType: String }

  connect() {
    this.refreshAccountTypes(this.accountTypeValue)
    this.refreshDetailTypes(this.detailTypeValue)
  }

  baseTypeChanged() {
    this.refreshAccountTypes()
    this.refreshDetailTypes()
  }

  accountTypeChanged() {
    this.refreshDetailTypes()
  }

  refreshAccountTypes(preselect) {
    const accountTypes = this.taxonomyValue[this.baseTypeTarget.value] || {}
    this.fillSelect(this.accountTypeTarget, Object.keys(accountTypes), "Select account type", preselect)
  }

  refreshDetailTypes(preselect) {
    const accountTypes = this.taxonomyValue[this.baseTypeTarget.value] || {}
    const detailTypes = accountTypes[this.accountTypeTarget.value] || []
    this.fillSelect(this.detailTypeTarget, detailTypes, "Select detail type", preselect)
  }

  fillSelect(select, values, promptText, preselect) {
    const options = [ `<option value="">${promptText}</option>` ]

    for (const value of values) {
      const selected = value === preselect ? " selected" : ""
      options.push(`<option value="${value}"${selected}>${this.humanize(value)}</option>`)
    }

    select.innerHTML = options.join("")
  }

  humanize(value) {
    return value.replaceAll("_", " ").replace(/\b\w/g, (letter) => letter.toUpperCase())
  }
}
