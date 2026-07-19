import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  open(event) {
    event.preventDefault()

    const whatsappTab = window.open("", "_blank")
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(this.urlValue, {
      method: "POST",
      headers: { "X-CSRF-Token": csrfToken, Accept: "application/json" }
    })
      .then((response) => response.json())
      .then((data) => {
        if (whatsappTab && data.deep_link) {
          whatsappTab.location.href = data.deep_link
        } else if (whatsappTab) {
          whatsappTab.close()
        }
        window.location.reload()
      })
      .catch(() => {
        if (whatsappTab) whatsappTab.close()
      })
  }
}
