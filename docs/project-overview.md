# Project Overview

This repository serves as a comprehensive showcase project for the Elixir programming language, designed to demonstrate various Elixir concepts, patterns, and best practices through practical examples.

## Purpose

### 1. Elixir Language Showcase

This Phoenix web application demonstrates:

- **Phoenix Framework**: Modern web development with LiveView
- **Elixir Patterns**: OTP, GenServers, supervision trees
- **Functional Programming**: Immutable data, pattern matching, pipe operators
- **Concurrency**: Actor model implementation with processes
- **Real-time Features**: WebSocket connections and live updates

### 2. Presentation Platform

The repository includes an integrated slides application built with Reveal.js that hosts presentations about Elixir. The slides are served directly from the Phoenix application at `/slides`.

## Repository Structure

```
├── lib/                    # Main Elixir application code
│   ├── gem/               # Core business logic and contexts
│   └── gem_web/           # Phoenix web layer (controllers, live views)
├── apps/slides/           # Reveal.js presentation application
│   ├── src/slides/        # Markdown slide files
│   └── src/themes/        # Custom presentation themes
├── docs/                  # Documentation and guides
│   └── slides-app.md      # Slides application documentation
└── priv/static/slides/    # Built presentation assets
```

## Slides Integration

The presentation slides are integrated into the Phoenix application:

- **Development**: Slides auto-rebuild during development
- **Content**: Written in Markdown with Reveal.js features
- **Themes**: Custom Iceberg-inspired design
- **Speaker Notes**: Full presenter view support
- **Navigation**: Keyboard shortcuts and overview mode

### Presentation Development Workflow

The repository includes a structured approach to presentation development:

1. **Draft Creation**: Presentations begin as detailed drafts in the `docs/` folder
   - Example: `docs/bet-on-elixir-draft.md` contains the full talk structure
   - Includes speaker notes, timing, code examples, and talking points
   - Allows for collaboration and refinement before implementation

2. **Implementation**: Drafts are converted to Reveal.js markdown format
   - Content is adapted for slide presentation format
   - Code examples are formatted for syntax highlighting
   - Speaker notes are added using Reveal.js `Note:` syntax

3. **Integration**: Final slides are built into the Phoenix application
   - Accessible via `/slides` endpoint
   - Auto-rebuild during development
   - Production-ready deployment

### Accessing Presentations

- Available at the same `/slides` endpoint

### Current Presentations

- **"Bet on Elixir"** (`docs/bet-on-elixir-draft.md`): An introduction to Elixir showcasing its power and convincing developers to invest in learning the language

