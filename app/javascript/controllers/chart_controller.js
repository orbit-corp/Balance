import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["svg", "range"]
  static values = { series: Array, key: { type: String, default: "net_kobo" }, sparkline: { type: Boolean, default: false }, cumulative: { type: Boolean, default: true } }

  connect() {
    this.days = this.sparklineValue ? (this.seriesValue || []).length : 30
    this.render()
    this.resizeHandler = () => this.render()
    window.addEventListener("resize", this.resizeHandler)
  }

  disconnect() {
    window.removeEventListener("resize", this.resizeHandler)
  }

  setRange(event) {
    this.days = parseInt(event.currentTarget.dataset.days, 10)
    for (const btn of this.rangeTargets) {
      const active = parseInt(btn.dataset.days, 10) === this.days
      btn.classList.toggle("bg-gradient-to-b", active)
      btn.classList.toggle("from-white", active)
      btn.classList.toggle("to-neutral-50", active)
      btn.classList.toggle("shadow-sm", active)
      btn.classList.toggle("text-neutral-900", active)
      btn.classList.toggle("text-neutral-500", !active)
    }
    this.render()
  }

  render() {
    const all = this.seriesValue || []
    const data = all.slice(-this.days)
    if (data.length === 0) return

    const sparkline = this.sparklineValue
    const key = this.keyValue
    const W = Math.max(sparkline ? 60 : 320, Math.floor(this.svgTarget.clientWidth || this.element.clientWidth || (sparkline ? 100 : 720)))
    const H = sparkline ? Math.floor(this.svgTarget.clientHeight || 32) : 220
    this.svgTarget.setAttribute("viewBox", `0 0 ${W} ${H}`)
    const padL = sparkline ? 2 : 4, padR = sparkline ? 2 : 4, padT = sparkline ? 2 : 14, padB = sparkline ? 2 : 26
    const innerW = W - padL - padR
    const innerH = H - padT - padB

    let running = 0
    const series = this.cumulativeValue ? data.map((d) => (running += d[key])) : data.map((d) => d[key])
    const values = this.cumulativeValue ? [0, ...series] : series
    const min = Math.min(...values)
    const max = Math.max(...values)
    const span = max - min || 1

    const x = (i) => padL + (data.length === 1 ? innerW / 2 : (i / (data.length - 1)) * innerW)
    const y = (v) => padT + innerH - ((v - min) / span) * innerH

    const line = series.map((v, i) => `${i === 0 ? "M" : "L"} ${x(i).toFixed(1)} ${y(v).toFixed(1)}`).join(" ")

    if (sparkline) {
      const lastX = x(series.length - 1).toFixed(1)
      const lastY = y(series[series.length - 1]).toFixed(1)
      this.svgTarget.innerHTML = `
        <path d="${line}" fill="none" stroke="#a3a3a3" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round" />
        <circle cx="${lastX}" cy="${lastY}" r="2" fill="#525252" />
      `
      return
    }

    const area = `${line} L ${x(series.length - 1).toFixed(1)} ${(padT + innerH).toFixed(1)} L ${x(0).toFixed(1)} ${(padT + innerH).toFixed(1)} Z`

    const labelIdx = this.tickIndexes(data.length, 6)
    const labels = labelIdx.map((i) => {
      const d = new Date(data[i].date)
      const text = d.toLocaleDateString("en-US", { month: "short", day: "numeric" })
      return `<text x="${x(i).toFixed(1)}" y="${H - 6}" fill="#737373" font-size="11" text-anchor="middle">${text}</text>`
    }).join("")

    const grid = [0.25, 0.5, 0.75].map((f) => {
      const gy = (padT + f * innerH).toFixed(1)
      return `<line x1="${padL}" y1="${gy}" x2="${W - padR}" y2="${gy}" stroke="#f0f0f0" stroke-width="1" />`
    }).join("")

    this.svgTarget.innerHTML = `
      <defs>
        <linearGradient id="chartFill" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#171717" stop-opacity="0.18" />
          <stop offset="100%" stop-color="#171717" stop-opacity="0" />
        </linearGradient>
      </defs>
      ${grid}
      <path d="${area}" fill="url(#chartFill)" />
      <path d="${line}" fill="none" stroke="#171717" stroke-width="2" stroke-linejoin="round" stroke-linecap="round" />
      ${labels}
    `
  }

  tickIndexes(length, count) {
    if (length <= count) return Array.from({ length }, (_, i) => i)
    const step = (length - 1) / (count - 1)
    return Array.from({ length: count }, (_, i) => Math.round(i * step))
  }
}
