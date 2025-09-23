# Fault Tolerance Demo Plan

## Purpose & Positioning
- Build an interactive visual that makes Elixir's fault-tolerance story tangible in under two minutes.
- Give presenters a "wow" moment that pairs with Slide 2.10 and contrasts against traditional try/catch error handling.
- Provide a reusable demo route (`/demo/fault-tolerance`) that stakeholders can explore after the talk.

## Audience & Learning Goals
- **Audience:** Engineers and engineering leaders familiar with concurrency pain points but new to the BEAM.
- **Key Takeaways:**
  - Supervision trees are simple to reason about.
  - Restart strategies can be configured per worker.
  - "Let it crash" keeps the system healthy rather than fragile.
- **Success Metric:** Viewers can explain the difference between `:permanent`, `:temporary`, and `:transient` restarts and why strategies like `:one_for_one` matter.

## Demo Narrative Flow
1. **Healthy System Baseline** – Show a stable tree with live status indicators and counters ticking up.
2. **Crash a Non-Critical Service** – Trigger a graceful shutdown on the cache worker and call out that it does not restart.
3. **Crash a Critical Service** – Brutally kill the DB worker, highlight the immediate restart animation, and point to the global counters.
4. **Escalate the Strategy** – Switch the supervisor to `:one_for_all`, crash the API worker, and demonstrate how the entire cluster restarts together.
5. **Debrief** – Pause with an activity log showing crash reasons and restart decisions alongside uptime that never resets.

## Interaction Model
- **Primary Controls:**
  - Restart strategy selector (`:one_for_one`, `:one_for_all`, `:rest_for_one`).
  - Crash payload selector (`normal`, `runtime`, `timeout`, `brutal_kill`).
  - Per-worker "Crash" buttons.
  - Single Iceberg-themed "Start/Stop Demo" toggle button that changes label and action based on system state.
- **Micro-interactions:**
  - Buttons scale to 105% and glow on hover, reset with an ease-out.
  - Status badges pulse subtly every 6 seconds to imply liveness.
  - Event log autoscrolls but pauses when the pointer enters the panel.

## Visual Layout & Tailwind Notes
- **Control Center Card (right column):** Stacked selects and toggle button in a compact panel sitting above the Worker Stateboard; leverages the Iceberg gradient for the primary action.
- **Main Canvas:**
  - SVG layer for lines (`stroke-dasharray` animated during restarts).
  - Process nodes sized 140×140 with soft translucent fills and status-colored borders (no drop shadows).
  - Each node houses a title, restart badge, status chip, and crash button.
- **Background:** Solid deep-slate base (`bg-[#11131c]`) keeps focus on the nodes—no global gradients.
- **Controls Accent:** The start/stop toggle uses an Iceberg gradient (`from-[#89b8c2] to-[#84a0c6]`) with subtle scaling to signal readiness, and lives alongside the selects in the side column.
- **Side Panel:** Sticky card listing workers, last crash reason, restart attempts, and a sparkline of recent activity.
  - Last exit reason shows a compact, single-line label: `:runtime_error | :timeout | :kill | :normal | :unknown`.
- **Bottom Stats Ribbon:** 4 KPI cards (uptime, total crashes, total restarts, health score).
- **Responsive Strategy:** Layout collapses to a stacked column on sub-1024px screens with controls pinned above the canvas.

## State Indicators & Animations
- **Color Palette** (aligns with existing demos):
  - Supervisor `#e2a478`, DB `#84a0c6`, Cache `#89b8c2`, API `#b4be82`.
- **Status States:**
  - `:running` – emerald border, steady indicator LED.
  - `:pending` – rose border while a crash is in-flight.
  - `:restarting` – amber border held briefly after the worker boots.
  - `:booting` – cyan border with pulse until fully online.
  - `:offline` – muted slate border.
- **Line Feedback:** Lines fade when a dependent is down; reignite with a sweep gradient when the child recovers.

## Process Architecture Snapshot
```
                                [Root Supervisor]
                                       |
               ┌───────────────────────┼───────────────────────┐
               │                       │                       │
        [DB Worker]              [Cache Worker]            [API Worker]
        restart: :permanent      restart: :temporary       restart: :transient
```

## Lifecycle Rules to Highlight
- **DB Worker (`:permanent`)** – Always restarted, showcases critical systems.
- **Cache Worker (`:temporary`)** – Demonstrates optional services staying down on purpose.
- **API Worker (`:transient`)** – Only resurrected on abnormal exits; normal stops remain down.
- **Strategy Switching:** Reinstate the tree with new configuration without tearing down the LiveView.

## Technical Implementation Outline
- **LiveView (`FaultToleranceLive`)**
  - Tracks supervisor pid, per-worker metadata, and aggregated counters in assigns.
  - Streams event log entries for efficient DOM updates.
  - Uses `Phoenix.PubSub` or direct message handling to react to worker crash notifications.
- **Supervisor Layer**
  - Root supervisor started under `BetOnElixir.Demos.Supervisor` with child `{DynamicSupervisor, name: DemoSup}`.
  - Workers registered via `Registry` for lookups and crash commands.
- **Worker Modules** (`Demo.DBWorker`, `Demo.CacheWorker`, `Demo.ApiWorker`)
  - Implement `GenServer` with explicit `terminate/2` reasons for clarity.
  - Support injected crash type to control exit reason per interaction.
- **Telemetry & Metrics**
  - Attach to `:telemetry` events for `[:demo, :worker, :exit]` and `[:demo, :worker, :restart]`.
  - Persist counters in ETS for resilience when LiveView reconnects.
- **UI Rendering**
  - SVG rendered with `Phoenix.Component` functions for nodes and edges.
  - Animations driven by CSS keyframes; LiveView only toggles state classes.

## Data & State Flow
1. User clicks "Crash" → LiveView handles event → sends `GenServer.cast` to worker.
2. Worker exits with specified reason → supervisor emits `:DOWN` message.
3. `FaultToleranceLive` receives message via `handle_info`, updates counters, and optionally triggers restart depending on strategy.
4. Assign updates broadcast via LiveView diff → UI animates to reflect new status.

## Implementation Milestones
- **Milestone 0 – Skeleton (0.5 day):** LiveView scaffolding, static tree, baseline counters.
- **Milestone 1 – Crash Mechanics (1 day):** Workers, supervisor wiring, exit handling, counters.
- **Milestone 2 – Visual Polish (1 day):** Animations, micro-interactions, responsive layout.
- **Milestone 3 – Strategy Switching (0.5 day):** Dropdown controlling supervisor restart strategy live.
- **Milestone 4 – QA & Instrumentation (0.5 day):** Telemetry hooks, basic tests, documentation.

## Testing Strategy
- LiveView tests that simulate crash events, assert counters via `has_element?/2` using DOM IDs (`#db-worker`, `#system-stats`).
- Worker unit tests verifying restart behavior for each exit type.
  - Assert the sidebar "Last exit" label maps to the compact set above.
- Integration test ensuring strategy updates propagate without restarting the LiveView process.

## Slide 2.10 Integration & Presenter Notes
- **Embed:** `<iframe data-src="/demo/fault-tolerance" height="720">` under the existing slide.
- **Presenter Cue:** "Watch what happens when I murder the database process—supervision restarts it before I finish the sentence."
- **Call to Action:** Encourage audience to scan a QR code (optional future enhancement) linking directly to the demo route.
- **Fallback:** If the demo is offline, slide still communicates the three worker types with code snippet and counters.

## Current Status (as of September 23, 2025)
- ✅ LiveView scaffolded with supervisor-tree visualization, controls, and real-time metrics.
- ✅ Session-scoped supervisor/worker stack implemented with dynamic registry and crash handling.
- ✅ UI refinements in progress: core layout complete; polishing worker card spacing and typography next.
- ⚠️ Outstanding: add more granular telemetry visual cues, finalize responsive tweaks, and integrate sound/QR decisions.

## Open Questions & Dependencies
- Confirm hosting strategy for demo (Fly staging vs. live on laptop).
- Decide whether we persist counters between sessions or reset per load.
- Determine if sound effects should accompany crashes (could be distracting).
- Align microcopy with overall presentation voice (e.g., "Crash" vs. "Trigger Failure").
