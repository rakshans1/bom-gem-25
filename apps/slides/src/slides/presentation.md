<!-- Slide 1 -->

<div class="container">
<div style="display: flex; align-items: anchor-center;">
<h1>Bet on Elixir</h1>
<img src="/images/elixir.png" alt="Elixir Logo" style="height: 8em; top: -30px; right: 70px; position: relative;">
</div>

<span style="top: -70px; position: relative;">
Why Elixir should be your next language
</span>

</div>

Note: Welcome everyone. I'm here to sell you on Elixir and convince you to learn it. This isn't just another programming language presentation.

---

<!-- Slide 1.1 -->

<div class="container">
<h2>Hi, I'm Rakshan Shetty</h2>

**Software Engineer @ invideo**

</div>

Note: Quick introduction - I'm Rakshan Shetty, working as a Software Engineer at InVideo. I'm excited to share why I believe Elixir is a language worth betting on.

---

<!-- Slide 2 -->

<div class="container">
<h2>What is Elixir?</h2>

**Elixir is a dynamic programming language designed for building scalable, fault-tolerant applications**
</div>

Note: Before we dive into impressive numbers, let's establish what Elixir actually is. It's not just another web framework - it's a completely different approach to building software.

--

<!-- Slide 2.1 -->

<div class="container">
<h2>Key Characteristics</h2>

<ul>
<li class="fragment" data-fragment-index="1">Built on the <strong>Erlang Virtual Machine (BEAM)</strong></li>
<li class="fragment" data-fragment-index="2"><strong>Functional programming</strong></li>
<li class="fragment" data-fragment-index="3"><strong>Actor model</strong></li>
<li class="fragment" data-fragment-index="4"><strong>"Let it crash" philosophy</strong></li>
<li class="fragment" data-fragment-index="5"><strong>Built-in distribution</strong></li>
</ul>
</div>

--

<!-- Slide 2.2 -->

<div class="container">
<h2>Functional ƛ</h2>

```elixir
"Elixir is cool!"
|> String.split(" ")
|> List.last()
|> String.replace_suffix("!", "")
|> String.upcase()
# => "COOL"
```
</div>

--

<!-- Slide 2.3 -->

<div class="container">
<h2>Immutable 🔒</h2>

```elixir
user = %{name: "Alice", status: :inactive}
new_user = %{user | status: :active}
# Original user remains unchanged
```
</div>

--

<!-- Slide 2.4 -->

<div class="container">
<h2>Pattern Matching ⚡</h2>

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
</div>

--

<!-- Slide 2.5 -->

<div class="container">
<ul>
<li class="fragment" data-fragment-index="1"><strong>Polymorphism</strong> via protocols</li>
<li class="fragment" data-fragment-index="2"><strong>Meta-programming</strong> with macros</li>
<li class="fragment" data-fragment-index="3">And more...</li>
</ul>
</div>

--

<!-- Slide 2.6 -->

<div class="container">
<h2>The Three Pillars</h2>

<ul>
<li class="fragment" data-fragment-index="1"><strong>Concurrency</strong> 🧵</li>
<li class="fragment" data-fragment-index="2"><strong>Fault Tolerance</strong> 🛡️</li>
<li class="fragment" data-fragment-index="3"><strong>Distribution</strong> 🌐</li>
</ul>
</div>

--

<!-- Slide 2.7 -->

<div class="container">
<h2>Concurrency 🧵</h2>

In Erlang VM, all code runs inside lightweight threads called **processes**.
</div>

--

<!-- Slide 2.8 -->

<div class="container">
<h2>What are Processes?</h2>

<ul>
<li class="fragment" data-fragment-index="1"><strong>Lightweight</strong> - millions can run concurrently (~2KB each)</li>
<li class="fragment" data-fragment-index="2"><strong>Isolated</strong> - share nothing, communicate via messages</li>
<li class="fragment" data-fragment-index="3"><strong>Fault-tolerant</strong> - "let it crash" philosophy</li>
<li class="fragment" data-fragment-index="4"><strong>Preemptively scheduled</strong> - fair execution across processes</li>
</ul>
</div>

--

<!-- Slide 2.9 -->

<div class="container">
<h2>Basic Process Example</h2>

<div class="r-stack">

<div class="fragment fade-out" data-fragment-index="4">

<div class="fragment" data-fragment-index="1">

```elixir
# Spawn a process
pid = spawn(fn -> end)
```

</div>

<div class="fragment" data-fragment-index="2">

```elixir
# Send messages
send(pid, {:hello, self()})
send(pid, {:add, 10, 20, self()})
```

</div>

<div class="fragment" data-fragment-index="3">

```elixir
# Receive Messages
receive do
  {:hi, from} -> IO.puts("Got greeting from #{inspect(from)}")
  {:result, sum} -> IO.puts("Sum is #{sum}")
end
```

</div>
</div>

<div class="fragment fade-in" data-fragment-index="4">

```elixir
pid = spawn(fn ->
  receive do
    {:hello, caller} ->
      send(caller, {:hi, self()})
    {:add, a, b, caller} ->
      send(caller, {:result, a + b})
  end
end)

send(pid, {:hello, self()})

receive do
  {:hi, from} -> IO.puts("Got greeting from #{inspect(from)}")
  {:result, sum} -> IO.puts("Sum is #{sum}")
end
```

</div>

</div>
</div>

--

<!-- Slide 2.10 -->

<!-- .slide: class="fullscreen" -->
<iframe data-src="/demo/processes"
        data-lazy
        width="100%"
        height="100%"
        frameborder="0"
        style="border-radius: 8px; background: #161821; border: 1px solid #1e2132;">
</iframe>

--

<!-- Slide 2.11 -->

<div class="container">
<h2>Concurrency Features</h2>

<ul>
<li class="fragment" data-fragment-index="1"><strong>Actor Model</strong> - Isolated processes communicate via messages</li>
<li class="fragment" data-fragment-index="2"><strong>Lightweight processes</strong> - Millions of processes, not OS threads</li>
<li class="fragment" data-fragment-index="3"><strong>Preemptive scheduling</strong> - Fair resource allocation</li>
<li class="fragment" data-fragment-index="4"><strong>Message passing</strong> - No shared state, no race conditions</li>
<li class="fragment" data-fragment-index="5"><strong>Fault isolation</strong> - Process crashes don't affect others</li>
</ul>
</div>

Note: Not OS threads - they're lightweight actors (2KB memory footprint), Cheap to create and destroy. Millions can run concurrently on a single machine. Isolated - one process crash doesn't affect others.

--

<!-- Slide 2.12 -->

<!-- .slide: class="fullscreen" -->
<iframe data-src="/demo/ping-pong"
        data-lazy
        width="100%"
        height="100%"
        frameborder="0"
        style="border-radius: 8px; background: #161821; border: 1px solid #1e2132;">
</iframe>

--

<!-- Slide 2.12a -->

<!-- .slide: class="fullscreen" -->
<iframe data-src="/demo/ping-pong-mailbox"
        data-lazy
        width="100%"
        height="100%"
        frameborder="0"
        style="border-radius: 8px; background: #161821; border: 1px solid #1e2132;">
</iframe>

Note: Watch both mailboxes fill while each process drains independently. The original ping-pong demo is still available on the previous slide for a lightweight comparison.

--

<!-- Slide 2.13 -->

<div class="container">
<h2>Fault Tolerance 🛡️</h2>

<ul>
<li class="fragment" data-fragment-index="1"><strong>The "Let It Crash" Philosophy</strong> - Embrace failures and recover gracefully</li>
<li class="fragment" data-fragment-index="2"><strong>Supervision Trees</strong> - Supervisors monitor child processes and restart them when they crash</li>
<li class="fragment" data-fragment-index="3"><strong>Error Propagation Strategy</strong> - Errors bubble up the supervision tree</li>
<li class="fragment" data-fragment-index="4"><strong>Restart Strategy</strong> - <code>:one_for_one</code>, <code>:one_for_all</code>, and <code>:rest_for_one</code></li>
<li class="fragment" data-fragment-index="5"><strong>Restart Type</strong> - <code>:permanent</code>, <code>:temporary</code>, and <code>:transient</code></li>
</ul>
</div>

Note: The "Let It Crash" Philosophy. Each level decides how to handle failures. System stays running even with component failures. Self-healing - processes restart with clean state. It's a fundamentally different way of building robust systems.

--

<!-- Slide 2.14 -->
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

<!-- Slide 2.15 -->

<div class="container">
<h2>Built-in Distribution 🌐</h2>

```elixir
# Connect nodes across machines
Node.connect(:"app@server2.com")

# Send messages across the network
send({:worker, :"app@server2.com"}, {:process_data, data})
```
</div>

Note: Distribution isn't an afterthought - it's built into the language. The same message passing that works locally works across the network.
