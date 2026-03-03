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

### Invitation & Member Management

Two mechanisms for joining an account: **join codes** (shareable `Account::JoinCode`, 12-char base58 formatted as `XXXX-XXXX-XXXX`) and **email invitations** (`Invitation` model with 7-day expiry token). Both create users with `member` role.

**Single-account enforcement:** A user can only belong to one account at a time. On join, existing active memberships are deactivated.

**Leave flow:** Members can voluntarily leave via `/:account_id/membership`. They can select recipes to take — these create `PendingRecipeTransfer` records tied to the identity. On joining/creating a new account, transfers are executed via `RecipeFork` (deep copy with shared Active Storage blobs). Owners cannot leave.

**Recipe forking:** `RecipeFork` service (`app/services/recipe_fork.rb`) deep-copies a recipe to a target account: duplicates all child records (ingredients, instructions, nutrition, tips), finds-or-creates matching tags, shares Active Storage blobs (zero file duplication). Sets `forked_from_id` for lineage tracking.

**Family hub:** The "Family" nav item points to `/:account_id/members` which combines member management, join code display, email invitations, and dietary profiles in one page.

### Routing Structure

- `/session`, `/signup`, `/onboarding` — public auth routes
- `/join`, `/join/:code` — join an account via code (public, requires auth)
- `/invitations/:token/accept` — accept email invitation (public, requires auth)
- `/identity/*` — access token and session management
- `/:account_id/*` — all account-scoped routes (dashboard, recipes, API)
- `/:account_id/members` — Family hub (members, join code, dietary profiles)
- `/:account_id/membership` — leave account flow
- `/:account_id/api/v1/*` — JSON API (recipes, meal plans, meal planning)

### Domain Models

All primary keys are string UUIDs. Key models:

- `Account` → `User` (membership with role) → `Identity` (global email identity)
- `Invitation` — email-based account invitations (token, expiry, acceptance tracking)
- `PendingRecipeTransfer` — tracks recipes selected for transfer between accounts
- `Recipe` → `RecipeIngredient`, `RecipeInstruction`, `RecipeNutritionData`, `RecipeTip` (nested attributes). Has optional `rating` (1–5 integer, nil = unrated) and `forked_from_id` for recipe lineage tracking.
- `MealPlan` → `MealPlanDay` → `MealPlanMeal` → `Recipe` (hierarchical, with servings and daily calorie targets)
- `Access` — polymorphic resource-level permissions
- `MagicLink`, `Session`, `AccessToken` — auth infrastructure

### Pagination

Uses Pagy gem (`config/initializers/pagy.rb`) with `pagy_countless` for "Load More" UX (no total count query). Default 12 items per page. `Pagy::Backend` included in `ApplicationController`, `Pagy::Frontend` in `ApplicationHelper`.

### Caching Strategy

Uses Solid Cache in production (`:memory_store` in dev). Cache strategy:

- **Touch chains:** Child models (`Ingredient`, `RecipeInstruction`, `RecipeNutritionData`, `RecipeTip`, `MealPlanDay`, `MealPlanMeal`) use `touch: true` on `belongs_to` to auto-invalidate parent `updated_at`/`cache_key`.
- **Russian-doll fragment caching:** `_recipe_card.html.erb` wrapped in `<% cache recipe %>` — auto-invalidated when recipe or any child record changes via touch chain.
- **Method-level caching:** `Recipe#to_meal_planning_response` cached via `Rails.cache.fetch("#{cache_key_with_version}/meal_planning_response")`.
- **USDA API caching:** `Usda::Client` caches search and food responses in `Rails.cache` with 24h TTL. Cache keys: `usda:search:#{sha256}` and `usda:food:#{fdc_id}`.

### Recipe Browser

The recipe index (`accounts/recipes#index`) supports search, sort, and filtering via model scopes on `Recipe`:
- `by_search(query)` — SQLite LIKE on title, description, ingredient name (left_joins + group)
- `by_cook_time(max_minutes)` — total prep+cook time filter
- `by_calorie_range(min, max)` — joins nutrition_data
- `by_min_rating(min)` — filters recipes with `rating >= min`
- `sorted_by(sort)` — `newest` (default), `alphabetical`, `quickest`, `most_used` (COUNT DISTINCT meal_plan_meals), `highest_rated` (COALESCE rating to 3 for unrated)

Pagination uses lazy Turbo Frames: each page renders a `turbo_frame_tag` for the next page with `loading: :lazy`, creating chained infinite scroll. The `_recipe_page` partial handles subsequent pages via Turbo Frame requests.

### API

Controllers under `app/controllers/accounts/api/v1/` inherit from `ActionController::API` (no views). Recipes expose `to_api_response` and `to_meal_planning_response` serialization methods directly on the model.

**Recipe Import API** — async import endpoints on the recipes controller:
- `POST /:account_id/api/v1/recipes/import_url` — accepts `{ url }`, returns `{ task_id, status }`
- `POST /:account_id/api/v1/recipes/import_photo` — accepts multipart `photos[]`, returns `{ task_id, status }`
- `GET /:account_id/api/v1/recipes/import_status/:task_id` — returns progress, result (when completed), or error
- `POST /:account_id/api/v1/recipes/import_confirm/:task_id` — saves recipe from completed task, accepts optional `recipe` overrides

**Dietary Profiles API** — CRUD endpoints with `DietRegistry.diet_names` in index meta:
- `GET/POST /:account_id/api/v1/dietary_profiles` — list active profiles / create
- `GET/PATCH/DELETE /:account_id/api/v1/dietary_profiles/:id` — show / update / soft-delete

**Shopping Lists API** — nested under meal plans:
- `GET /:account_id/api/v1/meal_plans/:meal_plan_id/shopping_list` — get latest list with items
- `POST /:account_id/api/v1/meal_plans/:meal_plan_id/shopping_list` — generate via `ShoppingListGenerator`
- `PATCH /:account_id/api/v1/meal_plans/:meal_plan_id/shopping_list/items/:id/toggle` — toggle item checked

**Meal Plan Generation API** — async AI generation and modification:
- `POST /:account_id/api/v1/meal_plans/generate` — creates plan, generates days, enqueues `MealPlanGenerationJob`, returns `{ task_id, meal_plan_id, status }`
- `GET /:account_id/api/v1/meal_plans/generate_status/:task_id` — poll async generation progress
- `POST /:account_id/api/v1/meal_plans/:id/swap_meal` — swap a meal's recipe (accepts `meal_id`, `recipe_id`)
- `POST /:account_id/api/v1/meal_plans/:id/regenerate_day` — clear and re-generate meals for one day via AI (synchronous)

### AI Service Layer

`Ai::Client` (`app/services/ai/client.rb`) wraps the Anthropic Claude API via the `anthropic` gem. Configured in `config/initializers/ai.rb` (default model: `claude-sonnet-4-20250514`, meal planning model: `claude-haiku-4-5-20251001`).

**Methods:**
- `chat(messages:, system:, max_tokens:)` — text completion
- `chat_with_tools(messages:, tools:, system:, max_tokens:)` — structured JSON via tool_use
- `vision(messages:, system:, max_tokens:)` — image + text input

**Credentials:** `Rails.application.credentials.dig(:ai, :anthropic, :api_key)`

**Error handling:** Retries 3× with exponential backoff (1s/2s/4s) on rate limits, server errors, and timeouts. Custom exceptions: `Ai::Client::ApiError`, `RateLimitError`, `TimeoutError`, `AuthenticationError`.

### AI Meal Plan Generation

`MealPlanGenerator` (`app/services/meal_plan_generator.rb`) orchestrates AI-powered meal plan creation using Haiku 4.5 for cost efficiency. Uses prompt caching (`cache_control: { type: "ephemeral" }`) on the static system prompt. Recipes are sent as integer indices (not UUIDs) to reduce token costs, with `@index_to_id` mapping indices back to UUIDs when populating the plan.

`RecipeSelector` (`app/services/recipe_selector.rb`) pre-filters and ranks recipes before sending to the AI:
- **Hard exclusion**: Removes recipes from recent past meal plans (adaptive N based on catalog size). Skipped when catalog < 20 recipes. Also hard-excludes 1-star rated recipes.
- **Soft scoring** (6 weighted factors): usage frequency (25%), recency decay (20%), diet compatibility (20%), user rating (15%), category fit (10%), newness bonus (10%). Rating scores: nil/3→50 (neutral), 2→20, 4→80, 5→100.
- **Category-proportional selection**: Ensures minimum representation (`MIN_PER_CATEGORY = 3`) per active meal type category
- Accepts `current_date:` override for deterministic testing

### AI Rate Limiting

`Ai::RateLimiter` (`app/services/ai/rate_limiter.rb`) enforces per-account rate limits on AI features using `Rails.cache` (Solid Cache in production). Limits configured in `config/initializers/ai_rate_limits.rb`, overridable via env vars (`AI_RATE_LIMIT_RECIPE_IMPORT`, etc.).

**Default limits:** recipe imports 20/hr, meal plan generations 10/hr, quick entry 30/hr.

**Controller integration:** `AiRateLimited` concern (`app/controllers/concerns/ai_rate_limited.rb`) provides `check_ai_rate_limit!(feature)` — returns 429 with `Retry-After` header for API, redirects with flash for web. Used as `before_action` in both web and API controllers.

**Testing:** Accepts `cache_store:` kwarg; tests inject `MemoryStore` since test env uses `:null_store`.

### MCP Server (Model Context Protocol)

Integrated via `fast-mcp` gem. Mounted at `/mcp` with HTTP/SSE transport. Allows Claude Desktop (and other MCP clients) to interact with the app via bearer token authentication.

**Configuration:** `config/initializers/fast_mcp.rb` — mounts middleware at `/mcp/sse` (SSE) and `/mcp/messages` (JSON-RPC). Tools auto-registered from `ApplicationTool.descendants`.

**Authentication:** `ApplicationTool` (`app/tools/application_tool.rb`) base class uses fast-mcp's `authorize` block to validate bearer tokens against `Identity::AccessToken`. Sets `Current.identity`, `Current.account`, `Current.user` from token. Account resolved from token's identity → user → account (not URL-scoped).

**Tools** (10 total in `app/tools/`):
- `ListRecipesTool`, `GetRecipeTool`, `CreateRecipeTool` — recipe CRUD
- `ListMealPlansTool`, `GetMealPlanTool`, `CreateMealPlanTool` — meal plan management
- `GenerateMealPlanTool` — AI-powered async generation (enqueues `MealPlanGenerationJob`)
- `GetDietaryProfilesTool` — active dietary profiles + available diets
- `GetNutritionInfoTool` — recipe nutrition with diet compatibility
- `GenerateShoppingListTool` — consolidated shopping list from meal plan

**Tool patterns:** Inherit from `ApplicationTool`. Use `tool_name`, `description`, `arguments` DSL (Dry::Schema). Return `{ content: [{ type: "text", text: JSON }] }`. Errors return `{ ..., isError: true }`. Use `next false` (not `return false`) in `authorize` blocks.

**Setup instructions:** Displayed on the Access Tokens page (`/identity/access_tokens`) with Claude Desktop config JSON template.

**Testing:** Tests in `test/tools/`. Set up `Current` via `set_current_from_token` in setup, then call `tool.call(...)` directly (skip `authorized?` in tool-specific tests; auth tested separately in `application_tool_test.rb`).

### AI Background Jobs

`AiBaseJob` (`app/jobs/ai_base_job.rb`) — base class for all AI jobs. Runs on dedicated `ai` queue (configured in `config/queue.yml`). Manages `AiTaskStatus` lifecycle automatically: pending → processing → completed/failed.

**`AiTaskStatus`** model tracks async AI job progress:
- `status` enum: `pending`, `processing`, `completed`, `failed` (with validated transitions)
- `result` JSON column for AI output, `error_message` for failures
- `progress_percentage` (0–100) for incremental updates
- Turbo Stream broadcasts on status AND progress changes to `[account, :ai_task_statuses]` stream
- Account-scoped with string UUID PK

**Subclassing pattern:** Implement `#execute(**args)` returning a Hash. Call `update_progress(n)` for incremental updates. Error handling and status transitions are automatic.

**Real-time progress UI:** Progress pages use `turbo_stream_from` to subscribe to broadcasts from `AiTaskStatus`. The `ai_progress_controller.js` Stimulus controller watches for status changes in the broadcast partial and redirects on completion/failure. Falls back to polling (via `fetch` every 2s) if WebSocket is unavailable. Reusable `shared/_ai_progress.html.erb` partial accepts `task`, `title`, `subtitle`, `completed_url`, `failed_url`, `poll_url`, and optional `milestones` hash.

### Recipe Import Pipeline

URL-based recipe import lives in `app/services/recipe_import/`. The pipeline:

1. **`UrlFetcher`** — HTTP fetch with redirect following (max 5), timeouts, user-agent
2. **`JsonLdParser`** — Primary extraction: parses `<script type="application/ld+json">` for schema.org Recipe data via Nokogiri. Handles `@graph` arrays, ISO 8601 durations, HowToStep objects.
3. **`AiExtractor`** — Fallback: sends stripped page text to Claude via `Ai::Client.chat_with_tools` with an `extract_recipe` tool definition. Truncates to 12K chars.
4. **`UrlImporter`** — Orchestrator: fetch → try JSON-LD → try AI → raise `ImportError`. Exposes `method_used` (`:json_ld` or `:ai`).

**Photo import:** `PhotoExtractor` sends images (Active Storage blobs or raw base64 hashes) to Claude vision via `Ai::Client.chat_with_tools` with the same `extract_recipe` tool. Supports multi-image for multi-page recipes. Max 10MB per image, JPEG/PNG/GIF/WebP.

**Jobs:** `RecipeImportJob < AiBaseJob` (URL pipeline), `RecipeImportPhotoJob < AiBaseJob` (photo pipeline). Both store results in `AiTaskStatus.result`.

**Controller flow:** Two entry points — `import_url` (URL form) and `import_photo` (file upload form). Both flow through shared `import_status` (polls with reload) → `import_review` (pre-fills recipe form). Task types: `recipe_import` (URL) and `recipe_photo_import` (photo) — used to route failure redirects back to the correct form.

**Testing pattern:** `UrlImporter` exposes a `fetch_html` private method that the test subclass (`TestableImporter`) overrides to return fixture HTML. `AiExtractor` and `PhotoExtractor` accept an `ai_client:` kwarg for injecting a fake client.

### AI Meal Plan Generation

`MealPlanGenerator` (`app/services/meal_plan_generator.rb`) orchestrates AI-powered meal plan creation.

**Flow:** User creates a plan (name, dates, participants) → selects "Generate with AI" with preference chips → `MealPlanGenerationJob` runs async → `MealPlanGenerator` fetches eligible recipes (must have nutrition data), calls Claude via `chat_with_tools` with an `assign_meals` tool → populates `MealPlanMeal` records → `PortionCalculator` creates per-participant portions.

**Key components:**
- `MealPlanGenerator` — accepts `ai_client:` kwarg for test injection. Validates minimum 3 recipes with nutrition data. Supports preference options (`PREFERENCE_OPTIONS` constant) and freeform special requests.
- `MealPlanGenerationJob < AiBaseJob` — task_type: `meal_plan_generation`. Args: `meal_plan_id:`, `preferences:`, `special_requests:`.
- Controller actions: `start_generate` (POST, creates plan + enqueues job) and `generate_status` (GET, polls with page reload).
- Stimulus controller: `ai_generate_controller.js` — toggles AI panel, manages preference chip selection, rewrites form action to `start_generate`.

**Testing:** Uses `FakeAiClient` class (defined in test file) that accepts a canned response. No API mocking needed.

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
