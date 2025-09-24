# Ping-Pong Mailbox Demo v2 Plan

## Purpose

- Evolve the existing ping-pong demo so we can _see_ two BEAM processes exchanging messages **and** the backlog that builds in each mailbox.
- Highlight that processes work independently: each drains its mailbox on its own cadence while the other continues operating.
- Reinforce actor-model concepts introduced on slide 2.8 and complement the spawning + fault tolerance demos with another premium UI moment.
- Ship this as a **brand-new** LiveView route (`/demo/ping-pong-mailbox` placeholder) while retaining the current `/demo/ping-pong` experience.

## Learning Outcomes

- Understand that every BEAM process owns a mailbox queue and processes messages sequentially.
- Observe how multiple messages can wait in a mailbox (>=3) while new ones arrive from other actors or the UI.
- Recognize that process A can continue receiving messages while process B is busy – no shared state or locks are needed.
- Connect the visualization to real Elixir code snippets so the audience can map UI events back to `send/2`, `receive`, and selective receive patterns.

## Experience Flow

1. **Idle**: two dormant process nodes (“Process A”, “Process B”) bookend the layout with empty mailbox stacks.
2. **Start Demo**: a primary CTA spins up both processes (spawned under a lightweight supervisor) and animates the first handshake (`:ping` → `:pong`).
3. **Mailbox Build-up**: a background task (or manual user action) injects messages into both mailboxes so we always show at least 3 queued envelopes spanning the same message palette defined in `docs/ping_pong_demo_plan.md` (ping, pong, data, task, result, gossip).
4. **Processing Loop**: each process pops messages at its own interval. Visual state switches from "waiting" to "processing" while the message animates across the center lane.
5. **Completion & Reset**: the demo can run continuously or be reset, keeping stats (total sent, queued, processed) visible for storytelling.

## Interface Blueprint

- **Shell**: reuse the Iceberg layout shell from `ProcessDemoLive` / `FaultToleranceDemoLive` (Layouts.demo, min-h-screen, gradient CTA, status dot system).
- **Canvas Layout**: responsive two-column grid (`lg:grid-cols-[360px_minmax(0,1fr)_360px]`) holding:
  - Left column: Process A card with status metrics stacked over a vertical mailbox queue.
  - Middle column: animated message highway with arcs connecting the two processes.
  - Right column: Process B mirror card.
- **Activity Bar**: bottom strip with controls, speed selector, and a condensed event stream (like the fault tolerance log but slimmer).

### Process Card Anatomy

- Title row with status dot (`idle`, `receiving`, `processing`, `blocked`).
- Stats chips: queued messages, processing rate, last message timestamp.
- Mailbox column: stack of rounded envelopes (`flex flex-col-reverse gap-2`, `phx-update="stream"`, each entry labeled with payload + arrival order).
- **Inline code snippet panel**: pastel clipboard-style block that renders the current clause/function the process is executing (e.g. `receive do {:ping, ref} -> ...`). Snippet should react to state transitions with soft transitions and borrow layout cues from reference images (monospace font, ellipses anchors).
- CTA button per process to simulate manual `send` (e.g., “Send custom ping to A”).

### Message Visualization

- Use color tokens from `docs/iceberg-ui-guidelines.md` combined with the original demo legend: ping (`#84a0c6`), pong (`#89b8c2`), data (`#b4be82`), task (`#e2a478`), result (`#c6c8d1`), gossip (`#9d79d6`).
- In-flight message chips animate across the center track using Tailwind `translate-x` utilities + `transition-all duration-500`. Layer faint dotted bezier lines to echo the mailbox routes.
- When a message is being processed, highlight its card in the mailbox with a glowing border (gradient from accent to transparent) and shrink once removed.
- Adjacent to the center lane, display the complementary code snippet for the _other_ process to reinforce send/receive semantics (e.g. left shows `send(process_b, ...)`, right shows `receive do`).

### Controls

- Primary CTA: `Start Conversation` / `Pause Simulation` toggle.
- Speed pills: Slow (900 ms), Normal (600 ms), Fast (300 ms) per-process processing interval.
- Queue injectors: quick buttons to enqueue `:ping`, `:pong`, task, result, gossip, and `{:data, n}` variations so the mailbox always reflects the multi-type color legend.
- Reset action to wipe stats and mailboxes.

## Interaction Notes

- Keep auto-injector active so each mailbox never empties entirely—queue up to 5 messages, then pause until one drains. The injector rotates through the message types/colors so the visual legend stays reinforced.
- When both processes run, allow them to pull from their mailbox independently. If one is paused (toggle per side), its queue grows while the other continues – perfect for narrating backpressure.
- Include hover micro-interactions (scale + ring) on buttons and mailbox cards per Iceberg guidelines.
- Provide a compact log (`@streams.events`) listing the last 5 message events (sent, queued, processed) with timestamps to reinforce the narrative.
- While a process executes, update the code snippet panel with a derived block (use helper to pretty-print the active clause) so viewers can tie the animation back to real Elixir.

## Simulation Mechanics

- Spin up two dedicated GenServers (`PingProcess`, `PongProcess`) supervised within the LiveView via `DynamicSupervisor` to keep the demo honest.
- Each GenServer stores its process pid and keeps no extra queue state; rely on actual mailbox behavior by sending tagged tuples (`{:enqueue, payload, ref}`).
- A LiveView controller process observes message flow via `Process.monitor/1` and the GenServer cast replies. To avoid polling mailboxes directly, maintain mirrored queues in the LiveView assigns updated whenever a process schedules work.
- Use LiveView `stream/3` for `:mailbox_a` and `:mailbox_b` so the UI updates efficiently while we append/remove messages.
- Processing loop: on `handle_info(:drain, state)`, pop next message (if any), broadcast to LiveView via `send(parent, {:processing, ref, payload, pid})`, simulate work with `Process.send_after(self(), :drain, interval)`.

## State & Assigns

- `@processes`: `%{a: %{pid: pid, status: :idle, speed: 600}, b: %{...}}`.
- `@streams.mailbox_a`, `@streams.mailbox_b`: latest queue (up to N=5) with metadata (`id`, `payload`, `inserted_at`).
- `@metrics`: `%{messages_sent: 0, messages_processed: 0, max_queue: %{a: 0, b: 0}}`.
- `@event_log`: stream of condensed messages for the UI.
- `@controls`: current mode, auto_injector boolean, shared speed.

## Visual Polish Checklist

- Background gradient stripe behind the center lane to echo other demos.
- Animated glow on the currently processing message chip (`animate-[pulse-soft]` custom keyframes defined in `app.css`).
- Muted skeletons while processes boot (opacity transitions on first render, similar to fault tolerance demo).

## Slide Integration

- Introduce a fresh slide (e.g., 2.9a) that embeds the new `/demo/ping-pong-mailbox` iframe while keeping the existing `/demo/ping-pong` slide intact.
- Add a dedicated slide note that clarifies the original ping-pong demo remains available for comparison.
- Update slide speaker notes to call out “watch the mailboxes fill while each process drains independently.”

## Implementation Steps

1. Scaffold new LiveView (`PingPongMailboxLive`) reusing layout shell + components from existing demos.
2. Build GenServer modules and supervisor wiring to manage real processes per session.
3. Implement LiveView assigns + streams for mailboxes, metrics, and event log.
4. Create animation helpers (`GemWeb.PingPongMailboxAnimations`) or inline helper functions for path coordinates.
5. Build a reusable code snippet component that can switch between the sender and receiver blocks based on process state.
6. Layer in Tailwind styling per Iceberg guidelines and ensure responsive behavior down to 768px.
7. Write LiveView tests covering mailbox streaming, speed toggle, log updates, and snippet swaps.
8. Update docs/slides to reference the new demo.

## Open Questions

- Do we show raw payloads (`{:ping, n}`) or translate into friendlier labels (“Ping #5”)?
- Should users be able to pause a single process to demonstrate uncontrolled backlogs explicitly?
- How many messages should we cap in the visual queue before collapsing into a counter + overflow indicator?
- Best approach for generating the live code snippet blocks: static template fragments, highlighted AST snippets, or simplified pseudo-code strings?
