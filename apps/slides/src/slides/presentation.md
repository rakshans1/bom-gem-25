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

<!-- Slide 2.12b -->

<div class="container">
<h2>Process Skeleton</h2>

<div style="display: flex; gap: 8rem; align-items: flex-start;">

<div style="flex: 1; margin-right: 2rem;">

```elixir
def start(args), do:
  spawn(Server, :init, [args], [])

def init(args) do
  state = initialise_state(args)
  loop(state)
end

def loop(state) do
  receive do
    {:handle, msg} ->
      state = handle(msg, state)
      loop(state)
    :stop -> terminate(state)
  end
end

def terminate(state), do: clean_up(state)
```

</div>

<div style="flex: 1;">

<div class="fragment" data-fragment-index="1">
<div class="mermaid">
%%{init: {'theme': 'dark', 'themeVariables': { 'darkMode': true }}}%%
flowchart TD
    A[Start] --> B[Initialise]
    B --> C[Loop]
    C --> C
    E[Stop] --> C
    C --> D[Terminate]

    style A fill:#e1f5fe,stroke:#01579b,stroke-width:3px,color:#000,font-size:20px,padding:15px
    style B fill:#f3e5f5,stroke:#4a148c,stroke-width:3px,color:#000,font-size:20px,padding:15px
    style C fill:#e8f5e8,stroke:#1b5e20,stroke-width:3px,color:#000,font-size:20px,padding:15px
    style D fill:#fff3e0,stroke:#e65100,stroke-width:3px,color:#000,font-size:20px,padding:15px
    style E fill:#ffebee,stroke:#b71c1c,stroke-width:3px,color:#000,font-size:20px,padding:15px

</div>
<style>
.mermaid {
    margin-top: 20px;
}
.mermaid svg {
    width: 320px !important;
    max-width: 100% !important;
    height: auto !important;
}
</style>

</div>
</div>

</div>
</div>

Note: This shows the basic skeleton of an Elixir process - every process follows this pattern of initialization, looping to handle messages, and graceful termination.

--

<!-- Slide 2.12c -->

<div class="container">
<h2>GenServer: Stateful Server Processes</h2>

<ul>
<li class="fragment" data-fragment-index="1"><strong>OTP Behavior</strong> - Standardized server pattern</li>
<li class="fragment" data-fragment-index="2"><strong>State Management</strong> - Maintains state between calls</li>
<li class="fragment" data-fragment-index="3"><strong>Synchronous & Asynchronous</strong> - call/cast operations</li>
<li class="fragment" data-fragment-index="4"><strong>Supervision Ready</strong> - Integrates with supervision trees</li>
</ul>
</div>

Note: GenServer is a behavioral pattern that abstracts the common server loop. It handles all the boilerplate for you - initialization, message handling, state management, and graceful shutdown.

--

<!-- Slide 2.12d -->

<div class="container" style="max-width: 100%; width: 100%;">
<style>
.container pre {
    width: 100% !important;
    max-width: none !important;
    font-size: 0.45em !important;
}
</style>
<div class="r-stack">

<div class="fragment fade-out" data-fragment-index="4">

<div>
<div class="fragment" data-fragment-index="1">

```elixir
defmodule Counter do
  use GenServer

  def start_link(initial_value \\ 0) do
    GenServer.start_link(__MODULE__, initial_value)
  end
end
```

</div>
</div>

<div>
<div class="fragment" data-fragment-index="2">

```elixir
  # Client API
  def get() do
    GenServer.call(__MODULE__, :get)
  end

  def increment() do
    GenServer.cast(__MODULE__, :increment)
  end
```

</div>
</div>

<div>
<div class="fragment" data-fragment-index="3">

```elixir
  # Server Callbacks
  def init(initial_value) do
    {:ok, initial_value}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  def handle_cast(:increment, state) do
    {:noreply, state + 1}
  end
```

</div>
</div>
</div>

<div class="fragment fade-in" data-fragment-index="4">

```elixir
defmodule Counter do
  use GenServer

  def start_link(initial_value \\ 0) do
    GenServer.start_link(__MODULE__, initial_value, name: __MODULE__)
  end

  # Client API
  def get() do
    GenServer.call(__MODULE__, :get)
  end

  def increment() do
    GenServer.cast(__MODULE__, :increment)
  end

  # Server Callbacks
  def init(initial_value) do
    {:ok, initial_value}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  def handle_cast(:increment, state) do
    {:noreply, state + 1}
  end
end
```

</div>

</div>
</div>

Note: This shows the separation between client API (what callers use) and server callbacks (internal implementation). GenServer handles all the message passing and state management for us.

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

<!-- Slide 2.12e -->

<div class="container">
<h2>Agent: Simple State Storage</h2>

<ul>
<li class="fragment" data-fragment-index="1"><strong>Simplified GenServer</strong> - Less boilerplate for state</li>
<li class="fragment" data-fragment-index="2"><strong>Function-based</strong> - Use functions to get/update state</li>
<li class="fragment" data-fragment-index="3"><strong>Perfect for simple state</strong> - Counters, caches, configs</li>
<li class="fragment" data-fragment-index="4"><strong>Built on GenServer</strong> - Same reliability, less code</li>
</ul>
</div>

Note: Agent is perfect when you need simple state storage without the complexity of GenServer callbacks. It's built on GenServer but provides a much simpler API for common use cases.

--

<!-- Slide 2.12f -->

<div class="container">
<div class="fragment" data-fragment-index="1">

```elixir
# Start an agent
{:ok, agent} = Agent.start_link(fn -> 0 end)

# Or with a name
Agent.start_link(fn -> 0 end, name: :counter)
```

</div>

<div class="fragment" data-fragment-index="2">

```elixir
# Get current state
count = Agent.get(:counter, fn state -> state end)
```

</div>

<div class="fragment" data-fragment-index="3">

```elixir
# Update state
Agent.update(:counter, fn state -> state + 1 end)
```

</div>

<div class="fragment" data-fragment-index="4">

```elixir
# Stop the agent
Agent.stop(:counter)
```

</div>

</div>

Note: Agent provides a clean, functional API for state management. No need for handle_call or handle_cast - just pass functions that transform the state.

--

<!-- Slide 2.12g -->

<div class="container">
<h2>When to Use What? 🤔</h2>

<table style="width: 100%; margin-top: 2rem; font-size: 0.8em;">
<thead>
<tr>
<th><strong>Pattern</strong></th>
<th><strong>Use Case</strong></th>
<th><strong>Complexity</strong></th>
<th><strong>Example</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td><strong>Process</strong></td>
<td>Custom concurrency patterns, one-off tasks</td>
<td>Low-level, more control</td>
<td>Background workers, custom protocols</td>
</tr>
<tr>
<td><strong>GenServer</strong></td>
<td>Stateful services with business logic</td>
<td>More boilerplate, full featured</td>
<td>Database connections, game state, APIs</td>
</tr>
<tr>
<td><strong>Agent</strong></td>
<td>Simple state storage and retrieval</td>
<td>Minimal boilerplate</td>
<td>Counters, caches, configuration</td>
</tr>
</tbody>
</table>

</div>

Note: This comparison helps you choose the right abstraction level. Start simple with Agent, move to GenServer when you need more control, and drop to raw processes only when you need maximum flexibility.

--

<!-- Slide 2.13 -->

<div class="container">
<h2>Fault Tolerance 🛡️</h2>

<strong>The "Let It Crash" Philosophy</strong> - Embrace failures and recover gracefully

</div>

Note: The "Let It Crash" Philosophy. Each level decides how to handle failures. System stays running even with component failures. Self-healing - processes restart with clean state. It's a fundamentally different way of building robust systems.

--

<!-- Slide 2.14 -->

<div class="container">
<h2>Supervisor 👨‍💼</h2>

<strong>Supervisors are special processes that monitor other processes (called children) and restart them when they crash.</strong>

<div class="fragment" data-fragment-index="1"><strong>Monitor</strong> - Watch child processes for failures</div>
<div class="fragment" data-fragment-index="2"><strong>Restart</strong> - Automatically restart crashed processes</div>
<div class="fragment" data-fragment-index="3"><strong>Manage</strong> - Start and stop child processes</div>
<div class="fragment" data-fragment-index="4"><strong>Apply Strategy</strong> - Decide how to handle failures</div>

</div>

Note: A supervisor is a process that monitors other processes (its children) and restarts them if they crash. This is the foundation of building fault-tolerant systems.

--

<!-- Slide 2.17 -->

<div class="container">
<h2>Supervision Trees 🌳</h2>

<strong>Supervisor trees create a hierarchy where supervisors can supervise other supervisors, creating a fault-tolerant system structure.</strong>

<div class="fragment" data-fragment-index="1"><strong>Error Propagation Strategy</strong> - Errors bubble up the supervision tree</div>
<div class="fragment" data-fragment-index="2"><strong>Restart Strategy</strong> - <code>:one_for_one</code>, <code>:one_for_all</code>, and <code>:rest_for_one</code></div>
<div class="fragment" data-fragment-index="3"><strong>Restart Type</strong> - <code>:permanent</code>, <code>:temporary</code>, and <code>:transient</code></div>

</div>

Note: Supervisors are the backbone of OTP's fault tolerance. They monitor child processes and restart them according to configured strategies when failures occur.

--

<!-- Slide 2.17a -->

<div class="container">
<div class="mermaid">
%%{init: {'theme': 'dark', 'themeVariables': { 'darkMode': true }}}%%
graph TD
    Phoenix["Application"]

    Phoenix --> Endpoint["Web"]
    Phoenix --> Services["Services"]

    Endpoint --> CowboySup["HTTP"]
    CowboySup --> Ranch1["Listener 1"]
    Ranch1 --> Conn1["Connection 1"]
    Ranch1 --> Conn2["Connection 2"]

    Services --> Ecto["Database"]
    Ecto --> Pool["Connection Pool"]
    Pool --> DBConn1["DB Connection 1"]
    Pool --> DBConn2["DB Connection 2"]

    Services --> PubSub["Cache"]
    PubSub --> LocalCache["Local Cache"]
    PubSub --> Registry["Process Registry"]
    Registry --> CacheWorker1["Cache Worker 1"]
    Registry --> CacheWorker2["Cache Worker 2"]

    Services --> TaskSup["Tasks"]
    TaskSup --> BgTasks["Background Tasks"]
    BgTasks --> EmailTask["Email Task"]
    BgTasks --> ReportTask["Report Task"]

    style Phoenix fill:#e1f5fe,stroke:#01579b,stroke-width:3px,color:#000,font-size:20px,padding:25px
    style Endpoint fill:#f3e5f5,stroke:#4a148c,stroke-width:3px,color:#000,font-size:20px,padding:25px
    style Services fill:#e8f5e8,stroke:#1b5e20,stroke-width:3px,color:#000,font-size:20px,padding:25px
    style Ecto fill:#fff3e0,stroke:#e65100,stroke-width:3px,color:#000,font-size:20px,padding:25px
    style PubSub fill:#ffebee,stroke:#b71c1c,stroke-width:3px,color:#000,font-size:20px,padding:25px
    style TaskSup fill:#f1f8e9,stroke:#33691e,stroke-width:3px,color:#000,font-size:20px,padding:25px
    style CowboySup fill:#fff8e1,stroke:#ff8f00,stroke-width:3px,color:#000,font-size:20px,padding:25px
    style Pool fill:#e3f2fd,stroke:#0277bd,stroke-width:3px,color:#000,font-size:20px,padding:25px

</div>
<style>
.mermaid {
    margin-top: 20px;
}
.mermaid svg {
    width: 1200px !important;
    max-width: 100% !important;
    height: auto !important;
}
</style>

</div>

Note: This shows a typical Phoenix application supervision tree. Each supervisor uses different restart strategies based on their role - web servers use :one_for_one, databases use :one_for_all for consistency, and task supervisors use :simple_one_for_one for dynamic children.

--

<!-- Slide 2.18 -->
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

<!-- Slide 2.19 -->

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
