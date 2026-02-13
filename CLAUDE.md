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

## Key Environment Variables

- `MULTI_TENANT` — enables multi-tenant mode (accounts created via signup flow)
- `RAILS_MASTER_KEY` — credentials decryption
