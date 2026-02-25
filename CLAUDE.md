# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- **Setup:** `bin/setup` (installs deps, prepares DB; add `--reset` to reset DB)
- **Dev server:** `bin/dev` (starts Rails + Tailwind watcher via Procfile.dev)
- **All tests:** `bin/rails test`
- **Single test file:** `bin/rails test test/models/recipe_test.rb`
- **Single test by line:** `bin/rails test test/models/recipe_test.rb:42`
- **Lint:** `bin/rubocop` (rubocop-rails-omakase style)
- **Lint autofix:** `bin/rubocop -a`
- **Security scan:** `bin/brakeman --quiet --no-pager`
- **Gem audit:** `bin/bundler-audit`
- **Full CI suite:** `bin/ci` (setup → rubocop → audits → brakeman → tests → seed test)

## Architecture

Rails 8.1 app (Ruby 3.4.4, SQLite3) for keto meal planning. Uses Hotwire (Turbo + Stimulus), Tailwind CSS, ImportMap, and the Solid stack (Cache, Queue, Cable).

### Multi-Tenancy

Account-scoped via URL pattern `/:account_id/...`. The `AccountSlug::Extractor` middleware (`app/middleware/`) parses the account ID from the URL and stores it in `env["meal_szn.account"]`. Toggled between single-tenant (default) and multi-tenant modes via `MULTI_TENANT` env var (see `config/initializers/multi_tenancy.rb`).

### Authentication

Passwordless magic link system. Flow: email → 6-char code (15 min expiry, character normalization O→0, I/L→1) → session creation. Sessions stored in signed cookies with 2-week expiry and IP/user-agent tracking. API uses bearer tokens (`Identity::AccessToken`) with read/write permissions via `Authorization` header.

Core concerns in `app/controllers/concerns/`:
- `Authentication` — session resumption, magic link consumption, bearer token auth
- `Authorization` — account access, role checks (owner > admin > member > system)
- `Authentication::ViaMagicLink` — magic link verification

`Current` (`app/models/current.rb`) is the thread-safe context holder for session/identity/user/account.

### Routing Structure

- `/session`, `/signup`, `/onboarding` — public auth routes
- `/identity/*` — access token and session management
- `/:account_id/*` — all account-scoped routes (dashboard, recipes, API)
- `/:account_id/api/v1/*` — JSON API (recipes, meal plans, meal planning)

### Domain Models

All primary keys are string UUIDs. Key models:

- `Account` → `User` (membership with role) → `Identity` (global email identity)
- `Recipe` → `RecipeIngredient`, `RecipeInstruction`, `RecipeNutritionData`, `RecipeTip` (nested attributes)
- `MealPlan` → `MealPlanDay` → `MealPlanMeal` → `Recipe` (hierarchical, with servings and daily calorie targets)
- `Access` — polymorphic resource-level permissions
- `MagicLink`, `Session`, `AccessToken` — auth infrastructure

### API

Controllers under `app/controllers/accounts/api/v1/` inherit from `ActionController::API` (no views). Recipes expose `to_api_response` and `to_meal_planning_response` serialization methods directly on the model.

### AI Service Layer

`Ai::Client` (`app/services/ai/client.rb`) wraps the Anthropic Claude API via the `anthropic` gem. Configured in `config/initializers/ai.rb` (default model: `claude-sonnet-4-20250514`).

**Methods:**
- `chat(messages:, system:, max_tokens:)` — text completion
- `chat_with_tools(messages:, tools:, system:, max_tokens:)` — structured JSON via tool_use
- `vision(messages:, system:, max_tokens:)` — image + text input

**Credentials:** `Rails.application.credentials.dig(:ai, :anthropic, :api_key)`

**Error handling:** Retries 3× with exponential backoff (1s/2s/4s) on rate limits, server errors, and timeouts. Custom exceptions: `Ai::Client::ApiError`, `RateLimitError`, `TimeoutError`, `AuthenticationError`.

### AI Background Jobs

`AiBaseJob` (`app/jobs/ai_base_job.rb`) — base class for all AI jobs. Runs on dedicated `ai` queue (configured in `config/queue.yml`). Manages `AiTaskStatus` lifecycle automatically: pending → processing → completed/failed.

**`AiTaskStatus`** model tracks async AI job progress:
- `status` enum: `pending`, `processing`, `completed`, `failed` (with validated transitions)
- `result` JSON column for AI output, `error_message` for failures
- `progress_percentage` (0–100) for incremental updates
- Turbo Stream broadcasts on status changes to `[account, :ai_task_statuses]` stream
- Account-scoped with string UUID PK

**Subclassing pattern:** Implement `#execute(**args)` returning a Hash. Call `update_progress(n)` for incremental updates. Error handling and status transitions are automatic.

### Design System

Defined in `app/assets/tailwind/application.css` using Tailwind v4 `@theme` block.

**Fonts** (Google Fonts, loaded in both layouts):
- `font-display` — Bitter (slab-serif, headings)
- `font-sans` (default body) — Nunito Sans

**Color tokens** — use these instead of raw Tailwind colors:
- `primary-*` (50–900) — Terracotta. Buttons, links, navbar, active states.
- `accent-*` (50–900) — Saffron/golden. Secondary CTAs, highlights.
- `warm-*` (50–900) — Warm neutrals. Text, borders, backgrounds. Replaces gray.
- `red-*`, `green-*`, `yellow-*` — kept as standard Tailwind for alerts, success, warnings.

**Custom CSS classes:**
- `.bg-warm-gradient` — warm body background (cream→peach gradient)
- `.card-warm` — frosted glass card with warm shadow
- `.nav-warm` — navbar gradient (dark→light terracotta)

**Conventions:**
- All page headings (`h1`, `h2`) use `font-display font-bold`
- Never use raw `emerald-*` or `gray-*` — use `primary-*` and `warm-*` tokens
- Public layout uses `.card-warm` for auth forms
- Body background uses `.bg-warm-gradient`, not flat color

## Key Environment Variables

- `MULTI_TENANT` — enables multi-tenant mode (accounts created via signup flow)
- `RAILS_MASTER_KEY` — credentials decryption

## Front End Design Aesthetics

You tend to converge toward generic, "on distribution" outputs. In frontend design, this creates what users call the "AI slop" aesthetic. Avoid this: make creative, distinctive frontends that surprise and delight. Focus on:

Typography: Choose fonts that are beautiful, unique, and interesting. Avoid generic fonts like Arial and Inter; opt instead for distinctive choices that elevate the frontend's aesthetics.

Color & Theme: Commit to a cohesive aesthetic. Use CSS variables for consistency. Dominant colors with sharp accents outperform timid, evenly-distributed palettes. Draw from themes that remind people of eating or a summer picnic for inspiration.

Motion: Use animations for effects and micro-interactions. Prioritize CSS-only solutions for HTML. Focus on high-impact moments: one well-orchestrated page load with staggered reveals (animation-delay) creates more delight than scattered micro-interactions.

Backgrounds: Create atmosphere and depth rather than defaulting to solid colors. Layer CSS gradients, use geometric patterns, or add contextual effects that match the overall aesthetic.

Avoid generic AI-generated aesthetics:
- Overused font families (Inter, Roboto, Arial, system fonts)
- Clichéd color schemes (particularly purple gradients on white backgrounds)
- Predictable layouts and component patterns
- Cookie-cutter design that lacks context-specific character

Interpret creatively and make unexpected choices that feel genuinely designed for the context. Vary between light and dark themes, different fonts, different aesthetics. You still tend to converge on common choices (Space Grotesk, for example) across generations. Avoid this: it is critical that you think outside the box!
