# Welcome to Elixir

A dynamic, functional language designed for building maintainable and scalable applications

---

## What is Elixir?

- Built on the Erlang Virtual Machine (BEAM)
- Fault-tolerant and concurrent
- Pattern matching and immutable data
- Actor model with lightweight processes

Note: Elixir leverages the battle-tested Erlang ecosystem

---

## Key Features

- **Pattern Matching** - Destructure data elegantly
- **Immutability** - Data doesn't change, reducing bugs
- **Actor Model** - Millions of lightweight processes
- **Fault Tolerance** - "Let it crash" philosophy

---

## Basic Syntax

```elixir
defmodule Greeter do
  def hello(name) do
    "Hello, #{name}!"
  end
end

Greeter.hello("World")
# => "Hello, World!"
```

---

## Pattern Matching

```elixir
# Destructuring tuples
{:ok, result} = {:ok, "Success!"}

# Matching lists
[head | tail] = [1, 2, 3, 4]
# head => 1, tail => [2, 3, 4]

# Function clauses
def factorial(0), do: 1
def factorial(n), do: n * factorial(n - 1)
```

--

## Processes & Concurrency

```elixir
# Spawn a process
pid = spawn(fn ->
  receive do
    {:hello, caller} ->
      send(caller, {:hello, "Hello from process!"})
  end
end)

# Send message
send(pid, {:hello, self()})

# Receive response
receive do
  {:hello, message} -> IO.puts(message)
end
```

--

## GenServer Example

```elixir
defmodule Counter do
  use GenServer

  def start_link(initial_value) do
    GenServer.start_link(__MODULE__, initial_value, name: __MODULE__)
  end

  def get_count do
    GenServer.call(__MODULE__, :get)
  end

  def increment do
    GenServer.cast(__MODULE__, :increment)
  end

  # Callbacks
  def init(initial_value), do: {:ok, initial_value}

  def handle_call(:get, _from, state), do: {:reply, state, state}

  def handle_cast(:increment, state), do: {:noreply, state + 1}
end
```

---

## Phoenix Framework

Elixir's web framework for building real-time applications

```elixir
defmodule MyAppWeb.PageLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, count: 0)}
  end

  def handle_event("increment", _params, socket) do
    {:noreply, assign(socket, count: socket.assigns.count + 1)}
  end
end
```

---

## Thank You!

Questions about Elixir?

- **Fault Tolerance**: Let it crash and recover
- **Concurrency**: Actor model with lightweight processes
- **Scalability**: Built for distributed systems
- **Productivity**: Expressive syntax and powerful tools