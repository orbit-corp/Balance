# Design Correction — align Layer 1 UI with shadcn dashboard-01

The current frontend does **not** match the reference (`https://ui.shadcn.com/view/new-york-v4/dashboard-01`). The backend is fine — **do not touch models, controllers, queries, routes, or tests.** This is a **frontend/design pass only.** Work it in its own clean context.

## What's wrong now
- Uses the default system font, not **Geist**.
- Has a top header bar and a narrow `max-w-lg` centered column — the reference is a **wide app shell with a fixed left sidebar**.
- Stat figures are tiny (`text-sm`); reference uses large `tabular-nums` numerals.
- Uses Tailwind default `gray-*`; reference uses a **neutral palette with a muted-foreground** convention and `rounded-xl` cards.

## Hard constraints (unchanged)
- **Plain Tailwind + ERB + Hotwire only.** Do NOT install shadcn, React, RubyUI, Phlex, or any UI/JS package. You are matching a *look*, not importing a library. Only permitted gem remains `bcrypt`.
- Tailwind v4 is in use (`@import "tailwindcss"` in `app/assets/tailwind/application.css`) — customize via an **`@theme` block in that CSS file**, not a JS config.
- Keep the existing **content**: the dashboard shows our period cards (Today / This week / This month → in, out, profit) and the recent-activity feed. **Do NOT copy the reference's main content area** (no charts, no data tables, no "Total Visitors" graph, no document table).
- Make the shell **responsive**: sidebar visible on desktop (`md:` and up), collapsed behind a hamburger toggle on mobile (a small Stimulus controller toggling a class — no new libraries). This preserves the mobile-first requirement while matching the desktop reference.

## Exact design tokens (measured from the live reference — use these)
Add to `app/assets/tailwind/application.css`:

```css
@import "tailwindcss";

@theme {
  --font-sans: "Geist", ui-sans-serif, system-ui, sans-serif;
  --font-mono: "Geist Mono", ui-monospace, monospace;

  --radius: 0.625rem;              /* base radius */
  /* card radius in reference ≈ 14px → use rounded-xl on cards */

  /* neutral palette (approximating the reference's lab() tokens) */
  --color-background: #ffffff;
  --color-foreground: #0a0a0a;
  --color-muted-foreground: #737373;   /* ≈ lab(48.5%), neutral-500 */
  --color-border: #e5e5e5;             /* ≈ neutral-200 */
  --color-sidebar: #fafafa;            /* subtle off-white sidebar */
  --color-accent: #f5f5f5;             /* hover/active nav item bg */
}
```

Then replace `gray-*` utilities across the views with `neutral-*` (or the theme tokens above) so secondary text uses the muted-foreground gray, borders use the border token, etc.

**Font loading:** self-host **Geist** and **Geist Mono** `.woff2` (from the official Geist font release / fontsource) into `app/assets/fonts/`, and add `@font-face` rules (font-display: swap) in the CSS. Self-hosting (not a Google Fonts `<link>`) keeps the 3G/low-bandwidth budget. Wire `--font-sans` to Geist as above.

**Stat-number typography:** large figures use `text-3xl font-semibold tabular-nums` (reference = 30px / 600 / tabular-nums). Add the `tabular-nums` utility to every money figure.

**Cards:** `rounded-xl border border-[--color-border] bg-white p-6` with a muted-foreground label (`text-sm text-[--color-muted-foreground]`), the large figure, then a small sub-line.

## Files to change
1. **`app/views/layouts/application.html.erb`** — replace the top-header layout with an **app shell**:
   - Fixed left **sidebar (`w-72` / 288px)**, `bg-[--color-sidebar]`, `border-r`. Structure mirroring the reference (top → bottom): brand ("Stubby" with a small logo mark) · a primary **"+ Quick add"** button (black, `bg-neutral-900 text-white rounded-md`) · nav group with items **Dashboard**, **Customers** (icons optional; use simple inline SVG or none) · a spacer · bottom group **Settings/Sign out** · a **user card** at the very bottom (business name + email, matching the reference's profile block).
   - Main column: a slim top bar (mobile hamburger toggle + page title on the left), then `yield` in a padded container (`p-6`, max width for readability).
   - Responsive: sidebar `hidden md:flex`; on mobile it's toggled open by the hamburger via a Stimulus controller.
2. **`app/views/dashboards/_period_cards.html.erb`** — restyle to the shadcn stat-card look: `rounded-xl border p-6`, muted label, **large `text-3xl font-semibold tabular-nums`** figure. Lead each card with the **profit** figure as the headline number, with **in** and **out** as smaller muted sub-lines beneath (keeps our content, adopts their visual hierarchy). Three cards, responsive grid (`grid-cols-1 md:grid-cols-3 gap-4`).
3. **`app/views/dashboards/show.html.erb`** — spacing/typography to match (section headings in the muted-foreground style, `tracking` normal). Keep the Add sale / Add expense actions and the recent feed.
4. **`app/views/transactions/_transaction.html.erb`** and **`_recent_feed`** — feed rows styled like clean list items (neutral text, `tabular-nums` amounts, subtle row separators).
5. Sweep the remaining views (`transactions/_form`, `customers/*`, `sessions/new`, `registrations/new`, `passwords/*`) to swap `gray-*` → neutral tokens and use Geist — so the whole app is visually consistent, not just the dashboard.

## Definition of done
- Body font computes to **Geist** in the browser.
- Desktop shows a 288px left sidebar matching the reference's structure; mobile collapses it behind a toggle.
- Dashboard stat figures are large `tabular-nums` in the neutral palette; cards are `rounded-xl` with muted labels.
- No charts/tables copied from the reference; our period-cards + feed content preserved.
- No new gems/JS libraries; plain Tailwind v4 `@theme` + self-hosted Geist only.
- All existing tests still pass; `bin/rubocop` + `bin/brakeman` clean.
- Report back with a screenshot of the dashboard at desktop and mobile widths for visual confirmation.
