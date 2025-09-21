# Note: dotenv-load disabled to prevent conflicts with ./bin/env
# All env loading is handled explicitly via ./bin/env script
set dotenv-load := false
set shell := ["bash", "-Eeuo", "pipefail", "-c"]


# Variables
app_name := env_var_or_default("APP_NAME", "gem")
mix_env := env_var_or_default("MIX_ENV", "dev")

export GIT_REVISION := `git rev-parse --short=12 HEAD 2>/dev/null | { read commit; if git diff --staged --quiet 2>/dev/null; then echo "$commit"; else echo "$commit-$(git diff --staged 2>/dev/null | sha256sum | cut -c1-8)"; fi; } || date +%s`

default:
    @just --list --unsorted

# Initialize project (first-time setup)
init:
    @echo "🚀 Initializing project..."
    @direnv allow || true
    @just deps
    # @just db-setup
    @echo "✅ Project initialized!"

# =============================================================================
# DEVELOPMENT
# =============================================================================
# Start development environment
server:
    #!/usr/bin/env bash
    set -e
    if [ ! -d deps ]; then
        echo "Dependencies not installed; running 'just deps' first..."
        just deps
    fi
    if [ ! -d node_modules ]; then
        echo "Node modules not installed; running 'pnpm install' first..."
        pnpm install
    fi
    echo "🚀 Starting Development Server"
    eval "$(./bin/env --overload -e .env.dev -e .env.dev.local)"
    iex --name "$APP_NAME" --cookie "$APP_NAME" -S mix phx.server

# =============================================================================
# DEPENDENCIES
# =============================================================================
# Install all dependencies
deps:
    @echo "📦 Installing dependencies..."
    @direnv allow || true
    @pnpm install
    mix deps.get
    @mix deps.compile
    @if [ "${CI:-}" != "true" ]; then just _livebook-setup; fi

# CI-specific dependency installation
ci-setup:
    @mix local.rebar --force
    @mix local.hex --force
    @pnpm install
    @mix deps.get
    @mix deps.compile

# =============================================================================
# DATABASE OPERATIONS
# =============================================================================
# Create database
db-create:
    #!/usr/bin/env bash
    set -e
    eval "$(./bin/env --overload -e .env.dev -e .env.dev.local)"
    mix ecto.create

# Generate new migration
db-gen-migration name:
    #!/usr/bin/env bash
    set -e
    eval "$(./bin/env --overload -e .env.dev -e .env.dev.local)"
    mix ecto.gen.migration {{name}}

# Run migrations
db-migrate:
    #!/usr/bin/env bash
    set -e
    eval "$(./bin/env --overload -e .env.dev -e .env.dev.local)"
    mix ecto.migrate

# Rollback migration
db-rollback *args:
    #!/usr/bin/env bash
    set -e
    eval "$(./bin/env --overload -e .env.dev -e .env.dev.local)"
    mix ecto.rollback {{args}}

# Reset development database
dev-reset:
    #!/usr/bin/env bash
    set -e
    eval "$(./bin/env --overload -e .env.dev -e .env.dev.local)"
    mix ecto.drop
    mix ecto.create
    mix ecto.migrate
    echo "✅ Development database reset"

# Reset test database
test-reset:
    #!/usr/bin/env bash
    set -e
    if [ -n "$CI" ]; then
        eval "$(./bin/env -e .env.test)"
    else
        eval "$(./bin/env --overload -e .env.test -e .env.test.local)"
    fi
    MIX_ENV=test mix ecto.drop
    MIX_ENV=test mix ecto.create
    MIX_ENV=test mix ecto.migrate
    echo "✅ Test database reset"

# =============================================================================
# LIVEBOOK
# =============================================================================

# Start Livebook server
livebook:
    #!/usr/bin/env bash
    set -e
    eval "$(./bin/env --overload -e .env.dev -e .env.dev.local)"
    export LIVEBOOK_HOME="$(pwd)/livebooks"
    export LIVEBOOK_DATA_PATH="$(pwd)/.livebook"
    export LIVEBOOK_TOKEN_ENABLED=false
    export LIVEBOOK_COOKIE="$APP_NAME"
    export LIVEBOOK_DEFAULT_RUNTIME="attached:$APP_NAME@$(hostname):$APP_NAME"
    export LIVEBOOK_IFRAME_PORT=9055

    if [[ $(uname) == "Darwin" ]] && [[ $(uname -m) == 'arm64' ]]; then
        export EXLA_FLAGS=--config=macos_arm64
    fi

    livebook server -p 9054

# Setup livebook
livebook-setup:
    @just _livebook-setup

# =============================================================================
# TESTING
# =============================================================================

# Run tests
test:
    #!/usr/bin/env bash
    set -e
    if [ -n "$CI" ]; then
        eval "$(./bin/env -e .env.test)"
    else
        eval "$(./bin/env --overload -e .env.test -e .env.test.local)"
    fi
    echo "🧪 Running tests..."
    MIX_ENV=test mix test

# =============================================================================
# QUALITY CHECKS (Read-only)
# =============================================================================
# IMPORTANT: Check commands must NEVER modify state (no installs, no mutations)
# They should fail fast with helpful messages if dependencies are missing

# Run all quality checks (read-only, excludes tests which are separate)
lint: check
check: check-fast

# Run fast quality checks (no tests, no installs, no mutations)
check-fast:
    @command -v mix >/dev/null || (echo "mix not found; run 'just init' first" && exit 1)
    @test -d deps || (echo "deps missing; run 'just deps' first" && exit 1)
    @test -d node_modules || (echo "node_modules missing; run 'pnpm install' first" && exit 1)
    @echo "🔍 Running quality checks..."
    @just check-format
    @just check-lint
    @just check-types-fast
    @echo "✅ All quality checks passed!"

# Check formatting across all languages
# Excludes all generated artifacts: node_modules, build outputs, static assets, caches
check-format:
    @echo "📝 Checking formatting..."
    @mix format --check-formatted --dry-run
    @echo "Checking Biome format (excluding Tailwind CSS v4 file)..."
    @biome check assets/js/ assets/vendor/ apps/ || echo "Note: Some Tailwind CSS v4 syntax not yet supported by Biome"

check-lint:
    @echo "🔍 Checking linting..."
    @mix compile --warnings-as-errors --force
    @mix credo --strict --min-priority normal
    @echo "Checking Biome lint (excluding Tailwind CSS v4 file)..."
    @biome lint assets/js/ assets/vendor/ apps/ || echo "Note: Some Tailwind CSS v4 syntax not yet supported by Biome"

check-types:
    @echo "🔍 Checking types..."
    @mix dialyzer
    @cd apps/slides && pnpm exec tsc --noEmit

check-types-fast:
    @echo "🔍 Checking TypeScript types..."
    @cd apps/slides && pnpm exec tsc --noEmit

# =============================================================================
# FIXES (Mutations)
# =============================================================================

# Auto-fix all fixable issues
fix:
    @echo "🔧 Auto-fixing issues..."
    @just fix-format
    @just fix-lint
    @echo "✅ Auto-fixes complete!"

# Fix formatting across all languages
# Excludes all generated artifacts to avoid touching build outputs
fix-format:
    @echo "📝 Fixing formatting..."
    @mix format
    @biome format --write assets/js/ assets/vendor/ apps/ || echo "Note: Some Tailwind CSS v4 syntax not yet supported by Biome"
    @nixfmt-classic flake.nix 2>/dev/null || true

fix-lint:
    @echo "🔍 Fixing linting..."
    @mix credo --strict --fix 2>/dev/null || true
    @biome lint --write --unsafe assets/js/ assets/vendor/ apps/ || echo "Note: Some Tailwind CSS v4 syntax not yet supported by Biome"

# =============================================================================
# PRIVATE HELPERS (prefix with underscore)
# =============================================================================
_livebook-setup:
    @mix escript.install hex livebook 0.14.5 --force
    @mkdir -p "$(pwd)/.livebook"
