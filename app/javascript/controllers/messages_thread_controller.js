import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["olderTrigger"]

  connect() {
    this.pinnedToBottom = true
    this.loading = false
    this.scrollToBottom()

    this.handleScroll = this.handleScroll.bind(this)
    this.element.addEventListener("scroll", this.handleScroll)

    this.handleImageLoad = this.handleImageLoad.bind(this)
    this.element.addEventListener("load", this.handleImageLoad, true)

    this.appendObserver = new MutationObserver(this.handleAppend.bind(this))
    this.listElement = this.element.querySelector("#messages_list")
    this.prependObserver = new MutationObserver(this.handlePrepend.bind(this))
    this.reconnectObservers()

    this.intersectionObserver = new IntersectionObserver(this.handleIntersect.bind(this), { root: this.element })
    if (this.hasOlderTriggerTarget) this.intersectionObserver.observe(this.olderTriggerTarget)

    this.layOutSeparators()
  }

  disconnect() {
    this.element.removeEventListener("scroll", this.handleScroll)
    this.element.removeEventListener("load", this.handleImageLoad, true)
    this.appendObserver?.disconnect()
    this.prependObserver?.disconnect()
    this.intersectionObserver?.disconnect()
  }

  olderTriggerTargetConnected(element) {
    this.loading = false
    this.intersectionObserver?.observe(element)
  }

  handleScroll() {
    const threshold = 120
    this.pinnedToBottom =
      this.element.scrollHeight - this.element.scrollTop - this.element.clientHeight < threshold
  }

  handleIntersect(entries) {
    for (const entry of entries) {
      if (entry.isIntersecting && !this.loading) {
        this.loading = true
        this.scrollHeightBeforePrepend = this.element.scrollHeight
        entry.target.click()
      }
    }
  }

  handleAppend() {
    this.layOutSeparators()
    if (this.pinnedToBottom) this.scrollToBottom()
  }

  handleImageLoad(event) {
    if (event.target.tagName === "IMG" && this.pinnedToBottom) this.scrollToBottom()
  }

  handlePrepend() {
    this.layOutSeparators()

    if (this.scrollHeightBeforePrepend == null) return

    this.element.scrollTop += this.element.scrollHeight - this.scrollHeightBeforePrepend
    this.scrollHeightBeforePrepend = null
  }

  scrollToBottom() {
    this.element.scrollTop = this.element.scrollHeight
  }

  layOutSeparators() {
    this.appendObserver?.disconnect()
    this.prependObserver?.disconnect()

    this.element.querySelectorAll(".day-separator").forEach((separator) => separator.remove())

    let previousDay = null
    this.element.querySelectorAll("[data-day]").forEach((message) => {
      const day = message.dataset.day
      if (day !== previousDay) {
        message.before(this.buildSeparator(message.dataset.dayLabel))
        previousDay = day
      }
    })

    this.reconnectObservers()
  }

  buildSeparator(label) {
    const separator = document.createElement("div")
    separator.className = "day-separator my-2 flex items-center gap-2 text-xs font-medium text-neutral-500"

    const lineBefore = document.createElement("div")
    lineBefore.className = "h-px flex-1 bg-neutral-200"

    const span = document.createElement("span")
    span.textContent = label

    const lineAfter = document.createElement("div")
    lineAfter.className = "h-px flex-1 bg-neutral-200"

    separator.append(lineBefore, span, lineAfter)
    return separator
  }

  reconnectObservers() {
    this.appendObserver?.observe(this.element, { childList: true })
    if (this.listElement) this.prependObserver?.observe(this.listElement, { childList: true })
  }
}
