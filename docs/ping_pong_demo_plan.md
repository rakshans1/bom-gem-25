# Process Ping-Pong Demo Plan

## Overview
A real-time, visual demonstration of Elixir's **message passing** between processes to complement the existing process spawning demo. This shows the **actor model** in action.

## Core Concept
- **Visual process network** with animated message passing
- **Different network topologies** to demonstrate various communication patterns
- **Real-time message visualization** with colored dots flying between processes
- **Interactive controls** for topology and speed

## Demo Features

### 1. Network Topologies
- **Chain** (A→B→C→D): Linear message passing
- **Ring** (A→B→C→D→A): Circular message flow
- **Hub & Spoke**: Central coordinator with worker processes

### 2. Visual Elements
- **Process nodes**: Colored circles representing individual processes
- **Animated messages**: Colored dots that travel between processes
- **Message types**: Different colors for ping, pong, data, task, result, gossip
- **Real-time stats**: Message count, current status

### 3. Message Types & Colors
- 🔵 **Ping** (#84a0c6) - Basic ping messages
- 🟢 **Pong** (#89b8c2) - Response to ping
- 🟡 **Data** (#b4be82) - Data packets
- 🟠 **Task** (#e2a478) - Work assignments (hub topology)
- ⚪ **Result** (#c6c8d1) - Task results (hub topology)
- 🟣 **Gossip** (#9d79d6) - Peer-to-peer communication

### 4. Interactive Controls
- **Topology selector**: Chain, Ring, Hub & Spoke
- **Speed control**: Fast (200ms), Normal (500ms), Slow (1s)
- **Start/Stop button**: Toggle demo on/off
- **Live message log**: Recent message activity

## Technical Implementation

### Process Simulation
- Each visual "process" represents a conceptual actor
- Messages are simulated events sent to the LiveView
- Animation calculated using timestamps and linear interpolation
- Different message patterns based on selected topology

### Animation System
- Messages travel from source to destination over 2 seconds
- Position calculated using timestamp-based progress
- CSS transitions provide smooth movement
- Messages auto-remove after animation completes

### Message Patterns
- **Chain**: Sequential message passing down the line
- **Ring**: Circular message flow with return to start
- **Hub**: Central process distributes tasks, receives results

## Integration with Presentation
- Complements existing process spawning demo (slide 2.7)
- Demonstrates **message passing** concept from slide content
- Shows **actor model** in visual, interactive way
- Perfect for illustrating "no shared state, no race conditions"

## Educational Value
- **Visual representation** of abstract concepts
- **Interactive exploration** of different patterns
- **Real-time demonstration** of concurrent messaging
- **Concrete example** of Elixir's actor model

## Route & Access
- URL: `/demo/ping-pong`
- Embedded in slides via iframe
- Standalone demo page with full controls
- Responsive design for different screen sizes