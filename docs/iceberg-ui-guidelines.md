# Iceberg UI Design Guidelines

These guidelines capture the visual language we use across demos and tooling in this project. They translate the Iceberg Reveal.js theme (`apps/slides/src/themes/custom.css`) into reusable LiveView styling primitives so new screens feel instantly on brand.

## Core Principles

- **Iceberg palette first**: Build every surface from the base colors below before introducing custom tones.
- **High contrast, low noise**: Prefer crisp borders, restrained gradients, and legible typography over heavy shadows.
- **Layers with intent**: Limit the number of surfaces in a stack; avoid "container inside container" framing unless it communicates hierarchy.
- **Micro-interactions**: Use subtle scale, color, or ring transitions to convey state changes without distracting from content.
- **Tailwind-native**: Compose styles with Tailwind class lists; skip `@apply`, third-party component kits, or inline scripts.

## Color System

| Token | Hex | Typical Usage |
| --- | --- | --- |
| `bg-void` | `#11131c` | Page background (`min-h-screen bg-[#11131c]`)
| `surface-primary` | `#1a1e2b` | Primary cards (`bg-[#1a1e2b]/95`)
| `surface-muted` | `#161821` | Secondary fills, modals
| `border-soft` | `rgba(255,255,255,0.10)` | Neutral borders (`border border-white/10`)
| `text-base` | `#c6c8d1` | Body copy (`text-slate-200`, `text-white/70`)
| `accent-blue` | `#84a0c6` | Links, gradients, icons
| `accent-cyan` | `#89b8c2` | Primary CTA gradients
| `accent-green` | `#b4be82` | Success/complete state badges
| `accent-amber` | `#e2a478` | Running/active status
| `accent-red` | `#e27878` | Stop/destructive actions
| `neutral-gray` | `#6b7089` | Disabled states, dividers

Keep gradients limited to Iceberg accents (e.g. `from-[#89b8c2]/90 to-[#84a0c6]/90`). Reserve vivid colors for focus elements so dashboards stay calm.

## Layout & Surfaces

- Wrap LiveView bodies in `Layouts.demo flash={@flash}` and use `min-h-screen` plus generous padding (`px-6 sm:px-10 py-10`).
- Target a **viewport-filling composition**: `min-h-[80vh] max-w-6xl mx-auto flex flex-col gap-8` keeps content balanced on desktop.
- Primary surfaces: `rounded-3xl border border-white/10 bg-[#1a1e2b]/95 backdrop-blur`. Secondary surfaces should lighten or darken the base subtly (`bg-[#11131c]/70`) without adding additional borders unless required.
- Avoid nesting identical cards (no "card inside card"). If a child needs differentiation, switch to `border-white/5 bg-white/5`, `divide-white/5`, or a simple top rule.

## Typography

- Use Inter for body text and uppercase micro labels with wider tracking: `text-xs uppercase tracking-[0.35em] text-white/50`.
- Headings are semi-bold (`font-semibold`) with clean white (`text-white`).
- Body copy sits at `text-sm text-white/70` for readability against dark surfaces.
- Numbers and telemetry use Fira Code via `font-mono` for precision cues.

## Components

### Buttons

- Primary: `bg-gradient-to-r from-[#89b8c2]/90 to-[#84a0c6]/90 text-slate-900 rounded-xl px-8 py-3 uppercase tracking-[0.15em] transition`.
- Destructive: `bg-[#e27878] text-[#11131c] rounded-xl px-6 py-2`.
- States: disable with `bg-[#6b7089]/60 text-white/70 cursor-not-allowed`.
- Avoid glow shadows; rely on color and scale (`hover:scale-[1.02]`) for feedback.

### Status Indicators

- Small dots (`h-3 w-3 rounded-full`) colored by state: idle gray, running amber, complete green.
- Pair with concise labels (`capitalize text-white font-semibold`).

### Cards & Lists

- Data panels: `rounded-2xl border border-white/10 bg-slate-900/60 p-5` or lighten with `bg-white/5` for nested list items.
- Streams: `flex items-center gap-3 rounded-2xl border border-white/5 bg-white/5 px-4 py-3 text-sm` ensures consistent spacing.

### Progress Indicators

- Track: `h-5 rounded-full border border-white/10 bg-slate-900/70`.
- Fill: `bg-gradient-to-r from-[#89b8c2] via-[#84a0c6] to-[#b4be82] text-[#161821] flex items-center justify-center`.
- Show value once progress >15% to avoid cramped text.

### Forms

- Always feed HEEx forms via `to_form/2` assigns.
- Inputs use the shared component: `<.input field={@form[:count]} type="select" class="w-full rounded-xl border border-white/10 bg-slate-900/70 px-4 py-2 text-sm font-medium text-white focus:ring-2 focus:ring-[#89b8c2]" />`.
- Disable with Tailwind states instead of custom inline styles.

## Motion & Interaction

- Apply `transition-all duration-200` on interactive elements.
- Use `hover:bg-white/10`, `hover:scale-[1.02]`, or `focus-visible:ring` to indicate affordances.
- `animate-pulse` is reserved for active status dots—not entire cards.

## Do & Avoid

**Do**
- Center layouts using flexible wrappers (`flex-1`, `gap-8`) so components breathe on wide monitors.
- Limit UI depth to two layers: background and one elevated surface.
- Reuse palette tokens to articulate state (e.g., amber for running processes, green for success).

**Avoid**
- Heavy drop shadows or glow effects.
- Deeply nested rounded containers that duplicate borders.
- Ad-hoc color values outside the Iceberg spectrum without a documented reason.
- Inline `<script>` tags or non-Tailwind utility CSS.

## Implementation Checklist

1. Start with the base shell:
   ```heex
   <Layouts.demo flash={@flash}>
     <div class="min-h-screen w-full bg-[#11131c] text-slate-200 px-6 sm:px-10 py-10">
       <div class="mx-auto flex min-h-[80vh] w-full max-w-6xl flex-col gap-8">
         <!-- content -->
       </div>
     </div>
   </Layouts.demo>
   ```
2. Compose primary cards with `rounded-3xl border-white/10 bg-[#1a1e2b]/95 backdrop-blur`.
3. Use gradient buttons and status dots per sections above.
4. Verify hover/focus states meet contrast guidelines.
5. Run `mix format` and `mix precommit` (after fixing sandbox config) before merging.

Keeping these guardrails in `docs/iceberg-ui-guidelines.md` lets us ship new demos that feel cohesive and premium without duplicating styling decisions.
