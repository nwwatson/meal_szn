# MealSzn System Overview

## What is MealSzn?

MealSzn is a meal planning application built for families who eat together but have different nutritional goals. It solves a common household problem: one family member follows a ketogenic diet, another is tracking calories for weight loss, a third is a growing teenager who needs extra protein, and they all sit down to the same dinner table. MealSzn lets a household build weekly meal plans from a shared recipe catalog while tracking per-person nutrition against individual dietary targets.

## The Problem

Most meal planning tools treat a household as a single eater. They generate a plan for one set of macros and one calorie target. In reality, families share meals but need different portion sizes and have different dietary constraints. Manually adjusting portions across seven days of three-plus meals for multiple people is tedious and error-prone.

Existing tools also tend to be diet-agnostic. They don't understand that a keto household needs to keep net carbs under 20g per person per day, or that a Mediterranean-leaning family member should be hitting 30-40% of calories from healthy fats. MealSzn is diet-aware from the ground up, with built-in macro profiles for Keto, Low-Carb, Paleo, Zone, Mediterranean, High-Protein, and Standard USDA guidelines.

## Core Concepts

### Accounts and Family Members

An account represents a household. Each account has members who log in (via passwordless magic links) and **dietary profiles** that represent everyone who eats — including children or family members who don't need their own login. A dietary profile stores a person's chosen diet type and daily calorie target, which drives portion calculations across all meal plans.

### Recipe Catalog

Recipes are the building blocks. Each recipe includes:

- **Ingredients** linked to USDA nutrition items for accurate macro calculation
- **Step-by-step instructions** with ordering
- **Nutrition data** (calories, fat, protein, carbs, fiber per serving)
- **Tags** for organization and filtering (e.g., "quick", "batch-cook", "kid-friendly")
- **Category** classification (breakfast, lunch, dinner, sides, snacks, sauces)
- **Tips** for preparation notes and variations

The USDA nutrition item linking is key: when an ingredient is mapped to a USDA entry, the system can auto-calculate per-serving macros rather than requiring manual data entry.

### Meal Plans

A meal plan covers a date range (typically a week). It contains:

- **Days**, each with assigned **meals** (a recipe at a specific meal slot with a serving count)
- **Participants** — the family members eating from this plan, each with their dietary profile
- **Portions** — per-person serving amounts for each meal, auto-suggested based on each participant's calorie target relative to the recipe's nutrition data

This structure means you can see at a glance: "On Tuesday, Mom gets 1.5 servings of the chicken stir-fry (hitting her 1,400 kcal keto target) while Dad gets 2 servings (hitting his 2,200 kcal standard target) and the kids split 1 serving."

### Shopping Lists

Once a meal plan is built, MealSzn generates a shopping list by aggregating all ingredients across every meal and every day, scaled by the total portions needed. If three different meals across the week call for chicken thighs, the shopping list consolidates them into a single line item with the combined quantity.

### Dietary Profiles and Macro Tracking

Each dietary profile references a diet from a built-in registry (`docs/macros.json`) that defines macro percentage ranges:

| Diet | Carbs | Fat | Protein |
|------|-------|-----|---------|
| Ketogenic | 5-10% | 70-75% | 20-25% |
| Low-Carb | 20-30% | 30-40% | 30-40% |
| Paleo | 30-40% | 30-40% | 25-35% |
| Zone | 40% | 30% | 30% |
| Mediterranean | 40-50% | 30-40% | 15-20% |
| High-Protein | 30-40% | 20-30% | 40-50% |
| Standard / USDA | 45-65% | 20-35% | 10-35% |

Combined with a daily calorie target, these percentages translate into gram-level macro targets (e.g., 1,800 kcal keto = ~20g carbs, 140g fat, 90g protein). The system uses these targets to suggest portions and to show per-day macro tracking against each participant's goals.

## How It All Fits Together

1. **Set up the household**: Create an account and add dietary profiles for each family member, selecting their diet type and daily calorie target.
2. **Build the recipe catalog**: Add recipes with ingredients, instructions, and nutrition data. Link ingredients to USDA items for auto-calculated macros. Tag and categorize for easy filtering.
3. **Create a meal plan**: Pick a week, assign recipes to each day's meal slots, and add family members as participants. The system suggests per-person portions based on each participant's calorie target.
4. **Review and adjust**: Check the per-day macro breakdown for each participant. Adjust portions or swap recipes to dial in the numbers.
5. **Generate a shopping list**: One tap produces a consolidated, quantity-scaled grocery list for the entire plan.

## Technical Architecture

MealSzn is a Rails 8.1 application using Hotwire (Turbo + Stimulus) for a responsive, SPA-like experience without a JavaScript framework. It uses SQLite for storage, Tailwind CSS for styling, and the Solid stack (Queue, Cache, Cable) for background processing and real-time updates.

The application is multi-tenant by design: each account is scoped via URL prefix (`/:account_id/...`), and all data is isolated per-account. Authentication is passwordless via magic link codes sent to email.

A JSON API (`/:account_id/api/v1/`) provides programmatic access for mobile clients and integrations, with bearer token authentication supporting read and write permission scopes.

For more on the authentication and authorization architecture, see [auth-security-specification.md](auth-security-specification.md).

## Future Direction

MealSzn aims to differentiate through AI-native features: AI-generated meal plans that respect dietary constraints, automatic recipe categorization by diet compatibility, and quick recipe import via URL parsing, photo/OCR extraction, and AI-assisted entry. A Claude Desktop MCP integration is planned for conversational meal planning workflows.
