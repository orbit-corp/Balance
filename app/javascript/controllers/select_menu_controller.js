import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["native", "button", "label", "menu"]
  static values = {
    includeBlank: Boolean,
    searchable: Boolean,
    searchPlaceholder: String,
    emptyMessage: String
  }

  connect() {
    this.refresh()
    this.outsideHandler = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    this.escapeHandler = (event) => {
      if (event.key === "Escape") this.close()
    }
    document.addEventListener("click", this.outsideHandler)
    document.addEventListener("keydown", this.escapeHandler)
  }

  disconnect() {
    document.removeEventListener("click", this.outsideHandler)
    document.removeEventListener("keydown", this.escapeHandler)
  }

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.classList.contains("hidden") ? this.open() : this.close()
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "true")
    if (this.searchInput) requestAnimationFrame(() => this.searchInput.focus())
  }

  close() {
    this.menuTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  select(event) {
    this.nativeTarget.value = event.currentTarget.dataset.value
    this.nativeTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.refresh()
    this.close()
    this.buttonTarget.focus()
  }

  refresh() {
    this.menuTarget.replaceChildren()
    this.searchInput = null
    this.emptyState = null
    if (this.searchableValue) this.addSearch()

    this.optionsContainer = document.createElement("div")
    this.optionsContainer.setAttribute("role", "listbox")
    this.menuTarget.append(this.optionsContainer)

    for (const child of this.nativeTarget.children) {
      if (child.tagName === "OPTGROUP") {
        this.addGroup(child)
      } else if (child.value || this.includeBlankValue) {
        this.addOption(child)
      }
    }

    this.refreshLabel()
  }

  addGroup(group) {
    const section = document.createElement("div")
    section.dataset.selectMenuGroup = ""

    const heading = document.createElement("div")
    heading.className = "px-2 pb-1 pt-2 text-[11px] font-medium tracking-wide text-neutral-400 uppercase first:pt-1"
    heading.textContent = group.label
    section.append(heading)

    for (const option of group.children) this.addOption(option, section)
    this.optionsContainer.append(section)
  }

  addOption(option, container = this.optionsContainer) {
    const item = document.createElement("button")
    item.type = "button"
    item.dataset.value = option.value
    item.dataset.selectMenuOption = ""
    item.dataset.action = "select-menu#select"
    item.setAttribute("role", "option")
    item.setAttribute("aria-selected", option.selected ? "true" : "false")
    item.className = "flex w-full cursor-pointer items-center rounded px-2 py-1.5 text-left text-sm text-neutral-700 hover:bg-neutral-100 aria-selected:bg-neutral-100 aria-selected:font-medium aria-selected:text-neutral-950"
    item.textContent = option.textContent
    container.append(item)
  }

  addSearch() {
    const wrapper = document.createElement("div")
    wrapper.className = "sticky top-0 z-10 border-b border-neutral-100 bg-white p-1"

    this.searchInput = document.createElement("input")
    this.searchInput.type = "search"
    this.searchInput.placeholder = this.searchPlaceholderValue
    this.searchInput.autocomplete = "off"
    this.searchInput.className = "block w-full rounded px-2 py-1.5 text-sm text-neutral-900 outline-none placeholder:text-neutral-400 focus:bg-neutral-50"
    this.searchInput.dataset.action = "input->select-menu#search"
    wrapper.append(this.searchInput)
    this.menuTarget.append(wrapper)
  }

  search(event) {
    const query = event.currentTarget.value.trim().toLowerCase()
    const options = [...this.optionsContainer.querySelectorAll("[data-select-menu-option]")]

    for (const option of options) {
      option.classList.toggle("hidden", !option.textContent.toLowerCase().includes(query))
    }

    for (const group of this.optionsContainer.querySelectorAll("[data-select-menu-group]")) {
      group.classList.toggle("hidden", !group.querySelector("[data-select-menu-option]:not(.hidden)"))
    }

    this.showEmptyState(options.every((option) => option.classList.contains("hidden")))
  }

  showEmptyState(show) {
    if (!this.emptyState) {
      this.emptyState = document.createElement("p")
      this.emptyState.className = "hidden px-2 py-4 text-center text-sm text-neutral-400"
      this.emptyState.textContent = this.emptyMessageValue
      this.optionsContainer.append(this.emptyState)
    }
    this.emptyState.classList.toggle("hidden", !show)
  }

  refreshLabel() {
    const option = this.nativeTarget.selectedOptions[0]
    const selected = option?.value
    this.labelTarget.textContent = selected ? option.textContent : this.nativeTarget.options[0]?.textContent
    this.labelTarget.classList.toggle("text-neutral-400", !selected)
    this.labelTarget.classList.toggle("text-neutral-900", Boolean(selected))
  }
}
