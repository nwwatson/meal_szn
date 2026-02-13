# MealSzn

A meal planning application built with Rails 8.1 for managing recipes, weekly meal plans, family dietary profiles, and shopping lists. Designed for families who share meals but have individual nutrition goals.

## Requirements

- Ruby 3.4.4
- SQLite3
- Node.js (see `.node-version`)

## Setup

```sh
bin/setup
```

This installs dependencies and prepares the database. Pass `--reset` to drop and recreate the database.

## Development

```sh
bin/dev
```

Starts the Rails server and Tailwind CSS watcher via `Procfile.dev`.

## Testing

```sh
bin/rails test              # Run all tests
bin/rails test test/models/  # Run a directory
bin/rails test test/models/recipe_test.rb      # Single file
bin/rails test test/models/recipe_test.rb:42   # Single test by line
```

## Code Quality

```sh
bin/rubocop          # Lint (rubocop-rails-omakase style)
bin/rubocop -a       # Lint with autofix
bin/brakeman --quiet --no-pager   # Security scan
bin/bundler-audit    # Gem vulnerability audit
bin/ci               # Full CI suite (setup, rubocop, audits, brakeman, tests, seed test)
```

## Architecture

### Stack

- **Framework:** Rails 8.1 with Hotwire (Turbo + Stimulus)
- **Database:** SQLite3 (all primary keys are string UUIDs)
- **Frontend:** Tailwind CSS, ImportMap
- **Background jobs / cache / WebSockets:** Solid Queue, Solid Cache, Solid Cable
- **Asset pipeline:** Propshaft
- **Deployment:** Kamal (Docker-based)

### Multi-Tenancy

Account-scoped via URL pattern `/:account_id/...`. The `AccountSlug::Extractor` middleware parses the account from the URL. Toggled between single-tenant (default) and multi-tenant modes via the `MULTI_TENANT` environment variable.

### Authentication

Passwordless magic link system:

1. User enters email
2. Receives a 6-character code (15 min expiry, with character normalization O->0, I/L->1)
3. Code verification creates a session (signed cookie, 2-week expiry)

API authentication uses bearer tokens (`Identity::AccessToken`) with read/write permissions.

### Key Features

- **Recipes** - Full CRUD with ingredients, instructions, nutrition data, tips, and tags. USDA nutrition item linking for auto-calculated macros.
- **Meal Plans** - Weekly plans with day-by-day meal assignments. Duplicate, edit, and manage across current/upcoming/past views.
- **Dietary Profiles** - Per-family-member profiles (including non-login members like kids) with diet selection and daily calorie targets. Supports diets from `docs/macros.json` (Keto, Paleo, Standard, Mediterranean, etc.).
- **Participants & Portions** - Assign family members to meal plans with auto-suggested per-person portions based on calorie targets. Inline portion editing with per-day macro tracking.
- **Shopping Lists** - Auto-generated from meal plans, aggregating ingredients across all meals and scaling by participant portions.
- **JSON API** - RESTful API at `/:account_id/api/v1/` for recipes and meal plans.

### Domain Models

```
Account
  -> Users (owner, admin, member roles)
  -> Dietary Profiles (family members)
  -> Recipes
     -> Ingredients, Instructions, Nutrition Data, Tips
  -> Meal Plans
     -> Meal Plan Days -> Meals -> Recipe
     -> Participants -> Portions (per-person servings)
     -> Shopping Lists -> Items
```

### Routing Structure

| Path | Purpose |
|------|---------|
| `/session`, `/signup`, `/onboarding` | Public auth routes |
| `/identity/*` | Access token and session management |
| `/:account_id/` | Dashboard |
| `/:account_id/recipes` | Recipe management |
| `/:account_id/meal_plans` | Meal plan management |
| `/:account_id/dietary_profiles` | Family dietary profiles |
| `/:account_id/settings` | User and account settings |
| `/:account_id/api/v1/*` | JSON API |

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `RAILS_MASTER_KEY` | Credentials decryption |
| `MULTI_TENANT` | Enables multi-tenant mode (accounts created via signup flow) |

## Deployment

Built for deployment with [Kamal](https://kamal-deploy.org). See `.kamal/` for configuration.

```sh
docker build -t meal_szn .
docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value> --name meal_szn meal_szn
```
