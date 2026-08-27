import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["olderTrigger", "scroller", "scrollButton"]

  connect() {
    this.pinnedToBottom = true
    this.loading = false
    this.scrollToBottom()

    this.handleScroll = this.handleScroll.bind(this)
    this.scroller.addEventListener("scroll", this.handleScroll)

    this.handleImageLoad = this.handleImageLoad.bind(this)
    this.scroller.addEventListener("load", this.handleImageLoad, true)

    this.appendObserver = new MutationObserver(this.handleAppend.bind(this))
    this.listElement = this.element.querySelector("#llm_messages")
    this.prependObserver = new MutationObserver(this.handlePrepend.bind(this))
    this.reconnectObservers()

    this.intersectionObserver = new IntersectionObserver(this.handleIntersect.bind(this), { root: this.scroller })
    if (this.hasOlderTriggerTarget) this.intersectionObserver.observe(this.olderTriggerTarget)

    this.layOutSeparators()
    this.updateScrollButton()
  }

  disconnect() {
    this.scroller.removeEventListener("scroll", this.handleScroll)
    this.scroller.removeEventListener("load", this.handleImageLoad, true)
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
      this.scroller.scrollHeight - this.scroller.scrollTop - this.scroller.clientHeight < threshold
    this.updateScrollButton()
  }

  handleIntersect(entries) {
    for (const entry of entries) {
      if (entry.isIntersecting && !this.loading) {
        this.loading = true
        this.scrollHeightBeforePrepend = this.scroller.scrollHeight
        entry.target.click()
      }
    }
  }

  handleAppend(mutations) {
    const addedElements = mutations.flatMap((mutation) =>
      Array.from(mutation.addedNodes).filter((node) => node.nodeType === Node.ELEMENT_NODE)
    )
    const userMessageAdded = addedElements.some((element) =>
      element.matches("[data-message-role='user']") || element.querySelector("[data-message-role='user']")
    )

    addedElements.forEach((element) => {
      element.classList.add("message-entering")
      element.addEventListener("animationend", () => element.classList.remove("message-entering"), { once: true })
    })

    this.layOutSeparators()
    if (this.pinnedToBottom || userMessageAdded) requestAnimationFrame(() => this.scrollToBottom(true))
    else this.updateScrollButton()
  }

  handleImageLoad(event) {
    if (event.target.tagName === "IMG" && this.pinnedToBottom) this.scrollToBottom()
  }

  handlePrepend() {
    this.layOutSeparators()

    if (this.scrollHeightBeforePrepend == null) return

    this.scroller.scrollTop += this.scroller.scrollHeight - this.scrollHeightBeforePrepend
    this.scrollHeightBeforePrepend = null
  }

  scrollToLatest() {
    this.scrollToBottom(true)
  }

  scrollToBottom(smooth = false) {
    this.scroller.scrollTo({ top: this.scroller.scrollHeight, behavior: smooth ? "smooth" : "auto" })
    this.pinnedToBottom = true
    this.updateScrollButton()
  }

  updateScrollButton() {
    if (!this.hasScrollButtonTarget) return

    const visible = !this.pinnedToBottom
    this.scrollButtonTarget.classList.toggle("pointer-events-none", !visible)
    this.scrollButtonTarget.classList.toggle("opacity-0", !visible)
    this.scrollButtonTarget.classList.toggle("translate-y-2", !visible)
    this.scrollButtonTarget.setAttribute("aria-hidden", String(!visible))
    this.scrollButtonTarget.tabIndex = visible ? 0 : -1
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
    if (this.listElement) this.appendObserver?.observe(this.listElement, { childList: true })
    if (this.listElement) this.prependObserver?.observe(this.listElement, { childList: true })
  }

  get scroller() {
    return this.hasScrollerTarget ? this.scrollerTarget : this.element
  }
}
