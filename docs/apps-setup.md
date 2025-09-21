# Apps Directory Setup

This document describes how the `apps/` directory is configured as a pnpm workspace with Turbo for managing multiple frontend applications within the Phoenix project.

## Overview

The `apps/` directory contains frontend applications that are built and served alongside the main Phoenix application. Each app is a separate package managed by pnpm workspace and built using Turbo for optimal performance.

## Workspace Configuration

### pnpm Workspace

The workspace is configured at the project root with the following files:

#### `pnpm-workspace.yaml`
```yaml
packages:
  - 'apps/*'
```

#### Root `package.json`
```json
{
  "name": "elixir-gem-mum-workspace",
  "private": true,
  "workspaces": [
    "apps/*"
  ],
  "scripts": {
    "build": "turbo run build",
    "clean": "turbo run clean && rm -rf node_modules",
    "lint": "turbo run lint",
    "fix": "turbo run fix"
  },
  "devDependencies": {
    "turbo": "^2.5.6"
  },
  "engines": {
    "node": ">=22",
    "pnpm": ">=9"
  }
}
```

### Turbo Configuration

Turbo is configured with `turbo.json` for build optimization:

```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "inputs": ["src/**/*.{ts,tsx,js,jsx,css}", "*.config.{ts,js}", "package.json"],
      "outputs": ["../../priv/static/**", "../../priv/static/sql-editor/**"]
    },
    "clean": {
      "cache": false
    },
    "lint": {
      "dependsOn": ["^build"]
    },
    "fix": {
      "dependsOn": ["^build"],
      "cache": false
    }
  }
}
```

## Phoenix Integration

### Static Assets

Apps build their output to `priv/static/` directories where Phoenix can serve them:
- Built files go to `priv/static/{app-name}/`
- Phoenix serves these at `/{app-name}/` routes

### Development Watcher

In `config/dev.exs`, pnpm watchers are configured for automatic rebuilds during development:

```elixir
watchers: [
  esbuild: {Esbuild, :install_and_run, [:gem, ~w(--sourcemap=inline --watch)]},
  tailwind: {Tailwind, :install_and_run, [:gem, ~w(--watch)]},
  pnpm: ["run", "build:watch", cd: Path.expand("../apps/slides", __DIR__)]
]
```

### Routing

Apps are routed through Phoenix controllers that serve the built static files:

```elixir
# In router.ex
get "/slides", SlidesController, :app
get "/slides/*path", SlidesController, :app
```

## Directory Structure

```
apps/
├── slides/                 # Reveal.js presentation app
│   ├── src/
│   │   ├── main.js         # Entry point
│   │   ├── themes/         # Custom themes
│   │   └── slides/         # Markdown slide files
│   ├── index.html          # HTML template
│   ├── package.json        # App dependencies
│   ├── vite.config.js      # Build configuration
│   └── tsconfig.json       # TypeScript config
└── [future-apps]/          # Additional apps go here
```

## Commands

### Development
```bash
# Install all dependencies
pnpm install

# Run all apps in development mode
pnpm dev

# Run specific app
pnpm --filter slides dev
```

### Building
```bash
# Build all apps
pnpm build

# Build specific app
pnpm --filter slides build

# Clean all builds
pnpm clean
```

### Managing Apps
```bash
# Add dependency to specific app
pnpm --filter slides add package-name

# Add dev dependency to workspace root
pnpm add -D package-name -w
```

## Adding New Apps

1. Create new directory in `apps/`
2. Initialize with `package.json`
3. Configure build output to `../../priv/static/{app-name}/`
4. Add routes in Phoenix router
5. Create controller to serve the app
6. Add watcher in `config/dev.exs` if needed

## Benefits

- **Isolation**: Each app has its own dependencies and build process
- **Shared tooling**: Common development tools (Turbo, TypeScript, etc.)
- **Optimized builds**: Turbo provides caching and parallel execution
- **Phoenix integration**: Seamless serving through Phoenix routes
- **Development workflow**: Hot reloading and automatic rebuilds