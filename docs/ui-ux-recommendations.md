# MealSzn UI/UX Recommendations

A screen-by-screen audit of the current frontend with prioritized recommendations for improving visual identity, usability, and overall experience.

---

## 1. Global: Visual Identity & Design System

### Problem
The app currently uses Tailwind defaults with no custom fonts, no CSS variables, and emerald-600 as the sole accent. Every screen looks like a Tailwind starter template — white cards, gray-50 backgrounds, system fonts. There is no visual personality that says "food" or "meal planning." The CLAUDE.md specifically calls out avoiding this exact aesthetic.

### Recommendations

**Typography** — Load two custom fonts via `<link>` or `@font-face`:
- A display/heading font with warmth and personality (e.g., Fraunces, Playfair Display, or Recoleta for an approachable food feel)
- A body font with good readability at small sizes (e.g., Source Serif 4, Newsreader, or DM Sans)
- Apply via Tailwind `@theme` or `fontFamily` config so all `font-sans` / `font-serif` references update globally

**Color System** — Replace ad-hoc emerald classes with CSS custom properties:
```css
:root {
  --color-primary: ...;      /* a warm, appetizing anchor color */
  --color-primary-light: ...;
  --color-accent: ...;       /* a contrasting pop for CTAs */
  --color-surface: ...;      /* card/panel background */
  --color-bg: ...;           /* page background */
}
```
Consider warmer tones: terracotta, saffron, olive, or burnt orange — colors that evoke food, kitchens, summer. Emerald green can remain but should be one note in a richer palette, not the entire identity.

**Background & Atmosphere** — The `bg-gray-50` body is flat. Options:
- Subtle warm gradient (`bg-gradient-to-br from-amber-50 to-orange-50`)
- Faint linen or paper texture via a tiling SVG background
- Geometric pattern in the header area (gingham, cross-hatch)

**Spacing & Rhythm** — Many views use `py-8 px-4` with `max-w-7xl`. This works but feels generic. Consider asymmetric margins, larger vertical rhythm between sections, and more breathing room on wide screens.

---

## 2. Navigation Bar

### Current State
Solid `bg-emerald-600` bar with white text. Standard horizontal nav links, dropdown user menu, hamburger on mobile. Functional but indistinguishable from any admin panel.

### Recommendations

- **Brand mark**: Replace the plain text "MealSzn" with a wordmark using the display font at a heavier weight, possibly with a subtle icon (fork, flame, leaf). Even just setting the logo in the display font creates immediate identity.
- **Nav shape**: Consider breaking out of the full-width solid bar. Options: a floating nav with rounded corners and subtle shadow (`mx-4 mt-4 rounded-2xl`), or a sidebar on desktop for more vertical real estate.
- **Active state**: Currently uses a background color swap. Could use an underline, a dot indicator, or a subtle bottom border for more visual interest.
- **Dietary Profiles link**: This is currently buried under Settings. Since profiles are core to the app's value (family members with individual goals), consider promoting it to the main nav or adding it as a secondary nav item.
- **Mobile nav**: The hamburger panel works but is minimal. Consider a slide-over drawer with user info and quick stats (current plan, recipe count) for a more native-app feel.

---

## 3. Sign In / Sign Up (Public Layout)

### Current State
Centered white card on gray-50. Plain "MealSzn" text header. Single email field + submit button. Minimal and clean but forgettable.

### Recommendations

- **Split layout**: On desktop, use a two-column layout — left side with a large illustration or hero image (food photography, illustrated vegetables, a kitchen scene), right side with the form. This immediately communicates what the app is about.
- **Brand moment**: The sign-in screen is the first impression. Use the display font for "MealSzn" at a large size. Add a tagline: "Meal planning for the whole family" or similar.
- **Magic link UX**: After sending the code, the transition to the verification screen should feel seamless. Add a visual indicator (animated envelope icon, countdown timer showing the 15-minute expiry). Currently it's just a flash message.
- **Footer**: The copyright footer on the public layout adds nothing. Remove or replace with a subtle brand mark.

---

## 4. Dashboard

### Current State
Three stat cards (Total Recipes, Categories, Quick Add), a Current Meal Plan section, and Recent Recipes list. Standard dashboard grid. The "Categories" card shows a static count (always 6, since categories are a fixed enum) — not useful information.

### Recommendations

- **Replace "Categories" card**: Show something actionable — recipes with unresolved ingredients, number of family members with profiles, or a "days until current plan ends" countdown.
- **Today's focus**: The dashboard should answer "What am I cooking today?" more prominently. If there's an active meal plan, today's meals should be the hero content — large cards with recipe names, prep/cook times, and quick links. Not buried in a subsection.
- **Weekly overview**: Add a compact 7-day strip showing which days have meals assigned and which are empty. This gives immediate context about the current plan's completeness.
- **Empty states**: The empty states (no recipes, no meal plan) are adequate but could be more inviting. Use illustrations or at least more descriptive guidance about what to do first.
- **Quick actions**: The "Quick Add" card only links to new recipe. Consider adding: "Create Meal Plan", "View Shopping List", "Add Family Member" as contextual quick actions based on what the user hasn't done yet (onboarding guidance).

---

## 5. Recipes Index

### Current State
Category pill filters, optional tag filters, 3-column card grid. Cards show title, category badge, description (2-line clamp), metadata (time, servings, calories), and tags. Functional and well-structured.

### Recommendations

- **Recipe images**: This is the single biggest visual upgrade possible. Even placeholder images (colored gradients based on category, or food emoji) would break up the wall of identical white cards. Long-term, support user-uploaded photos.
- **Card hierarchy**: All cards look identical — same size, same layout. Consider making the first card larger (featured recipe), or varying card heights based on content. A masonry layout would add visual interest.
- **Search**: There's no text search. For a growing recipe catalog, a search bar above the filters is essential.
- **Sort options**: No way to sort by recently added, prep time, calories, etc. Add a sort dropdown next to the filter pills.
- **Category filter UX**: The pill filters work but don't communicate the current filter state strongly enough. Consider a more prominent active state — filled background with a checkmark, or a visual indicator showing you're in a filtered view.
- **Empty card states**: When filtered to a category with no recipes, the message "No recipes found" could suggest adding one in that category specifically.

---

## 6. Recipe Detail (Show)

### Current State
Single white card with bordered sections: header, nutrition grid, ingredients list, numbered instructions, tips. Clean information hierarchy with emerald accents.

### Recommendations

- **Hero area**: If/when recipe images are supported, a full-width hero image at the top would transform this page. Even without images, the header area could be more dramatic — a colored banner based on category, larger typography.
- **Nutrition display**: The 5-column grid of big numbers works but is purely informational. For a diet-focused app, add context: "This fits a keto profile" or show a visual macro ring/bar chart showing the fat/protein/carb ratio. A small donut chart would communicate the macro split instantly.
- **Ingredient interaction**: Currently a static bullet list. Consider checkboxes so users can mark off ingredients while cooking (similar to the shopping list). This is a common and beloved feature in recipe apps.
- **Instruction interaction**: The numbered steps are clear. Consider larger step numbers, more vertical spacing between steps, and a "cooking mode" button that shows one step at a time in a large-text overlay (for reading from across the kitchen).
- **"Add to Meal Plan" prominence**: This button is in the top-right corner of the header, competing with Edit and Delete. As a primary action, it should be more prominent — perhaps a sticky bottom bar on mobile, or a larger button below the recipe content.
- **Source link**: If `@recipe.source` is a URL, it should be a clickable link. Currently it appears as plain text.
- **Print-friendly**: Recipe pages are a classic candidate for print stylesheets. A `@media print` rule that hides nav, buttons, and shows a clean single-column layout would be a thoughtful touch.

---

## 7. Recipe Form (New/Edit)

### Current State
Multi-section form with nested dynamic fields (ingredients, instructions, tips) managed by Stimulus controllers. Nutrition auto/manual toggle. Long vertical form.

### Recommendations

- **Progressive disclosure**: The form shows everything at once (basic info, tags, ingredients, instructions, tips, nutrition). For new recipes, this can be overwhelming. Consider collapsible sections that expand on click, or a multi-step wizard flow.
- **Ingredient entry**: The qty / unit / name row works but is cramped on mobile. Consider stacking on small screens. The USDA linking flow (currently only available after save via the show page) should be accessible during ingredient entry.
- **Drag to reorder**: Instructions and ingredients should be reorderable via drag-and-drop. The step_numbering Stimulus controller auto-numbers, but users can't rearrange steps visually.
- **Preview**: No way to see what the recipe will look like while editing. A live preview panel or a "Preview" tab would reduce the save-check-edit cycle.
- **Auto-save / draft**: Long forms risk losing work. Consider auto-saving drafts via Turbo or localStorage.
- **Bulk import hint**: The form is optimized for manual entry. A prominent link to "Import from URL" or "Paste recipe text" (future AI feature) would be valuable at the top of the new recipe form.

---

## 8. Meal Plans Index

### Current State
Grouped sections (Current, Upcoming, Past) with cards showing name, date range, duration, meal/day counts, and calorie target. "New Meal Plan" button in header.

### Recommendations

- **Visual timeline**: The current/upcoming/past grouping works logically but is text-heavy. Consider a visual timeline or calendar strip that shows plans on a horizontal axis, making it immediately clear when plans are active and where there are gaps.
- **Card richness**: Meal plan cards are sparse. Adding a mini day-breakdown (color-coded dots for days that have meals vs empty days), a participant count, or a macro summary would make the index more scannable.
- **Current plan prominence**: The current active plan should visually stand out — a colored border, a "Now" badge, or simply being rendered at 1.5x the size of other cards.
- **Past plans**: Past plans are listed but not especially useful in the current format. Consider collapsing them behind a "Show past plans" toggle to reduce clutter.

---

## 9. Meal Plan Detail (Show)

### Current State
Header with plan name, date range, action buttons. Participant bar with color-coded dots. Day cards with meal breakdowns by type (breakfast/lunch/dinner/snack), per-meal calorie display, inline portion editing, and per-participant daily macro totals.

This is the most complex and information-dense screen. It works but is visually monotonous — every day card looks identical.

### Recommendations

- **Calendar/grid view**: Consider an alternative view mode: a week grid where columns are days and rows are meal types. This gives a bird's-eye view and makes gaps obvious. The current vertical stack of day cards works for detail but makes it hard to see the week at a glance.
- **Today highlight**: If viewing the current plan, today's day card should have a visual accent (colored left border, different background) so it's immediately identifiable when scrolling.
- **Macro visualization**: The text-based macro totals are hard to scan. Replace or supplement with small progress bars or sparkline charts showing actual vs. target for each participant. Color coding (green = on target, amber = close, red = off) already exists in the helper but isn't visually impactful as plain text.
- **Add meal inline**: Currently, adding a meal requires going to a recipe's show page and clicking "Add to Meal Plan." Consider an inline "+" button on each meal type slot that opens a recipe picker directly within the day card.
- **Participant macro comparison**: On plans with multiple participants, it's useful to see side-by-side macro comparisons. The current layout lists them vertically. A small table or stacked bar chart per day would be more informative.
- **Empty day slots**: Days with no meals show a single italic line. Make empty slots more actionable — a dashed-border area with "Add breakfast", "Add lunch" placeholder buttons.

---

## 10. Shopping List

### Current State
Clean two-section layout (To Buy / Checked Off) with checkboxes, progress bar, regenerate/delete buttons. Well-executed for its simplicity.

### Recommendations

- **Group by category**: Shopping lists show items alphabetically. Grouping by grocery store section (produce, dairy, meat, pantry) would make the list more practical for shopping. This requires ingredient categorization data but is a high-value feature.
- **Quantity display**: Ensure quantities are prominent and easy to read at a glance. Consider bold quantities with lighter ingredient names.
- **Share/export**: A "Copy to clipboard" or "Share" button that generates a plain-text shopping list for sharing via text message. Many people share grocery duty.
- **Mobile optimization**: This is likely the most-used screen on mobile (at the grocery store). The touch targets for checkboxes should be generous. Consider a full-row tap to toggle rather than requiring a precise checkbox click.
- **Swipe to check**: On mobile, a swipe gesture to check off items would be faster than tapping the checkbox. Achievable with a Stimulus controller and CSS transforms.

---

## 11. Dietary Profiles

### Current State
Table layout with name, diet, calories, linked user, and edit/remove actions. Accessed via Settings. Basic CRUD.

### Recommendations

- **Card layout over table**: Profiles represent family members — they have personality. Cards with the person's name prominently displayed, their diet type as a badge, a visual macro breakdown ring, and their calorie target would be more engaging than a data table.
- **Promote access**: As noted in the nav section, dietary profiles are too buried. They're central to the app's value proposition.
- **Macro visualization**: When a diet and calorie target are set, show the computed macro gram targets visually — not just in the form preview but on the profile card. A three-segment bar (fat/protein/carbs) color-coded and labeled makes the profile feel real.
- **Avatar/icon**: Let users pick a color or emoji for each family member. This ties into the participant color coding in meal plans and makes the system feel more personalized.

---

## 12. Settings

### Not reviewed in detail but likely a simple account settings page.

### Recommendation
- Ensure it provides clear navigation to Dietary Profiles, Account management, and Session/API token management. Consider making it a sidebar-tabbed layout rather than a single page if it grows.

---

## 13. Cross-Cutting UX Issues

### Animations & Transitions
- **Page transitions**: There are no page transition animations. Turbo Drive swaps content instantly, which is fast but jarring. A subtle fade or slide transition on `turbo:before-render` would smooth navigation.
- **Flash messages**: Currently static colored boxes. They should auto-dismiss after 5 seconds with a fade-out animation. Consider toast-style notifications that slide in from the top or bottom.
- **Modal transitions**: Modals appear/disappear instantly (hidden class toggle). Add enter/leave transitions — fade the backdrop, scale-up the dialog.
- **List animations**: When items are added or removed (ingredients, shopping list items), animate the insertion/removal rather than having them appear/disappear.

### Responsive Design
- **Recipe form on mobile**: The ingredient row (qty + unit + name + remove) is too cramped. Stack the fields vertically on small screens.
- **Meal plan day cards on mobile**: The macro totals section with multiple participants gets very narrow. Consider hiding detailed macros behind a tap-to-expand on mobile.
- **Touch targets**: Several interactive elements (the portion edit click target, the shopping list checkbox, the meal delete X) are too small for comfortable thumb tapping. Minimum 44x44px per Apple/Google guidelines.

### Accessibility
- **Focus management**: Modal opening/closing doesn't trap or manage focus. Users tabbing through the page can tab behind the modal.
- **ARIA attributes**: Modals lack `role="dialog"`, `aria-modal="true"`, and `aria-labelledby`. Dropdowns lack `aria-expanded`.
- **Color contrast**: Some gray-400/gray-500 text on white backgrounds may not meet WCAG AA contrast ratios.
- **Skip navigation**: No skip-to-content link for keyboard users.

### Performance & Polish
- **Loading states**: No loading indicators for async operations (USDA search, add to meal plan, portion save). Users don't know if their action was registered.
- **Optimistic updates**: The shopping list toggle and portion edit could update the UI immediately and revert on failure, rather than waiting for the server response.
- **Error handling**: Async fetch calls in Stimulus controllers don't show user-facing errors on failure. Network errors are silently swallowed.

---

## Priority Order

If I had to rank these by impact-to-effort ratio:

1. **Custom fonts + color system** (global identity lift, moderate effort)
2. **Dashboard redesign** ("What am I cooking today?" focus, moderate effort)
3. **Flash message auto-dismiss + modal transitions** (polish, low effort)
4. **Recipe card images / placeholders** (visual variety, moderate effort)
5. **Macro visualization** (donut charts or progress bars on recipe show + day cards, moderate effort)
6. **Navigation brand mark + active states** (identity, low effort)
7. **Shopping list mobile optimization** (practical UX, low effort)
8. **Recipe search** (essential utility, moderate effort)
9. **Meal plan calendar/grid view** (power feature, higher effort)
10. **Sign-in page redesign** (first impression, moderate effort)
