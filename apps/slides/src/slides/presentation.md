<!-- Slide 1 -->

# Bet on Elixir

Note: Welcome everyone. I'm here to sell you on Elixir and convince you to learn it. This isn't just another programming language presentation.

---

<!-- Slide 2 -->

## What is Elixir?

**Elixir is a dynamic programming language designed for building scalable, fault-tolerant applications**

Note: Before we dive into impressive numbers, let's establish what Elixir actually is. It's not just another web framework - it's a completely different approach to building software.

--

<!-- Slide 2.1 -->

## Key Characteristics

<ul>
<li class="fragment" data-fragment-index="1">Built on the <strong>Erlang Virtual Machine (BEAM)</strong></li>
<li class="fragment" data-fragment-index="2"><strong>Functional programming</strong></li>
<li class="fragment" data-fragment-index="3"><strong>Actor model</strong></li>
<li class="fragment" data-fragment-index="4"><strong>"Let it crash" philosophy</strong></li>
<li class="fragment" data-fragment-index="5"><strong>Built-in distribution</strong></li>
</ul>

--

<!-- Slide 2.2 -->

## Functional ƛ

```elixir
"Elixir is cool!"
|> String.split(" ")
|> List.last()
|> String.replace_suffix("!", "")
|> String.upcase()
# => "COOL"
```

--

<!-- Slide 2.3 -->

## Immutable 🔒

```elixir
user = %{name: "Alice", status: :inactive}
new_user = %{user | status: :active}
# Original user remains unchanged
```

--

<!-- Slide 2.4 -->

## Pattern Matching ⚡

```elixir
case fetch_user(id) do
  {:ok, %User{role: :admin}} -> "Admin access granted"
  {:ok, %User{role: :user}} -> "User access granted"
  {:error, :not_found} -> "User not found"
  _ -> "Access denied"
end

with {:ok, user} <- fetch_user(id),
     {:ok, account} <- fetch_account(user.id),
     true <- account.active? do
  {:ok, "Welcome #{user.name}!"}
else
  {:error, reason} -> {:error, reason}
  false -> {:error, "Account inactive"}
end
```

--

<!-- Slide 2.5 -->

<ul>
<li class="fragment" data-fragment-index="1"><strong>Polymorphism</strong> via protocols</li>
<li class="fragment" data-fragment-index="2"><strong>Meta-programming</strong> with macros</li>
<li class="fragment" data-fragment-index="3">And more...</li>
</ul>

--

<!-- Slide 2.6 -->

## Concurrency 🧵

In Erlang VM, all code runs inside lightweight threads called **processes**. We can literally create millions of them.

--

<!-- Slide 2.7 -->

<!-- .slide: class="fullscreen" -->
<iframe data-src="/demo/processes"
        data-lazy
        width="100%"
        height="100%"
        frameborder="0"
        style="border-radius: 8px; background: #161821; border: 1px solid #1e2132;">
</iframe>

--

<!-- Slide 2.8 -->

## Concurrency Features

<ul>
<li class="fragment" data-fragment-index="1"><strong>Actor Model</strong> - Isolated processes communicate via messages</li>
<li class="fragment" data-fragment-index="2"><strong>Lightweight processes</strong> - Millions of processes, not OS threads</li>
<li class="fragment" data-fragment-index="3"><strong>Preemptive scheduling</strong> - Fair resource allocation</li>
<li class="fragment" data-fragment-index="4"><strong>Message passing</strong> - No shared state, no race conditions</li>
<li class="fragment" data-fragment-index="5"><strong>Fault isolation</strong> - Process crashes don't affect others</li>
</ul>

Note: Not OS threads - they're lightweight actors (2KB memory footprint), Cheap to create and destroy. Millions can run concurrently on a single machine. Isolated - one process crash doesn't affect others.

--

<!-- Slide 2.9 -->

<!-- .slide: class="fullscreen" -->
<iframe data-src="/demo/ping-pong"
        data-lazy
        width="100%"
        height="100%"
        frameborder="0"
        style="border-radius: 8px; background: #161821; border: 1px solid #1e2132;">
</iframe>

--

<!-- Slide 2.10 -->

## Fault Tolerance 🛡️

<ul>
<li class="fragment" data-fragment-index="1"><strong>The "Let It Crash" Philosophy</strong> - Embrace failures and recover gracefully</li>
<li class="fragment" data-fragment-index="2"><strong>Supervision Trees</strong> - Supervisors monitor child processes and restart them when they crash</li>
<li class="fragment" data-fragment-index="3"><strong>Error Propagation Strategy</strong> - Errors bubble up the supervision tree</li>
<li class="fragment" data-fragment-index="4"><strong>Restart Strategy</strong> - <code>:one_for_one</code>, <code>:one_for_all</code>, and <code>:rest_for_one</code></li>
<li class="fragment" data-fragment-index="5"><strong>Restart Type</strong> - <code>:permanent</code>, <code>:temporary</code>, and <code>:transient</code></li>
</ul>

Note: The "Let It Crash" Philosophy. Each level decides how to handle failures. System stays running even with component failures. Self-healing - processes restart with clean state. It's a fundamentally different way of building robust systems.

--

<!-- Slide 2.11 -->
<!-- .slide: class="fullscreen" -->
<iframe data-src="/demo/fault-tolerance"
        data-lazy
        width="100%"
        height="100%"
        frameborder="0"
        style="border-radius: 8px; background: #161821; border: 1px solid #1e2132;">
</iframe>

Note: The "Let It Crash" Philosophy. Each level decides how to handle failures. System stays running even with component failures. Drive the crash narrative using docs/fault-tolerance-demo-plan.md so every interaction lands the fault-tolerance story, and fall back to the code snippet if the iframe is unavailable.

--

## Built-in Distribution

<!-- Slide 2.12 -->

```elixir
# Connect nodes across machines
Node.connect(:"app@server2.com")

# Send messages across the network
send({:worker, :"app@server2.com"}, {:process_data, data})
```

Note: Distribution isn't an afterthought - it's built into the language. The same message passing that works locally works across the network.
