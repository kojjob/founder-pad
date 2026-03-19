# Design System Documentation: High-End B2B SaaS Editorial

## 1. Overview & Creative North Star

### Creative North Star: "The Midnight Architect"
This design system rejects the "boxed-in" aesthetic of legacy SaaS. Our North Star is **The Midnight Architect**—a philosophy that treats the UI as a vast, dark landscape where data is illuminated, not just displayed. We prioritize high-density information through sophisticated tonal layering rather than physical boundaries. 

The goal is an editorial-grade experience that feels bespoke. We achieve this by breaking the rigid, predictable grid with intentional asymmetry—such as offset headers or varying column widths—and utilizing a typography scale that balances the authority of a broad sans-serif with the technical precision of a monospace font. This is a system for power users who demand clarity and a premium feel.

---

## 2. Colors

Our palette is rooted in deep, atmospheric navies and charcoals, punctuated by high-energy accents.

### Surface Hierarchy & Nesting
We define depth through a "Material-First" logic. Instead of using shadows to lift elements, we use background shifts. 
- **The Base:** `surface` (#0b1326) is your canvas.
- **The Container:** Use `surface_container` (#171f33) for primary workspace areas.
- **The Inset:** Use `surface_container_lowest` (#060e20) for "well" styles or background areas that should feel recessed.
- **The Lift:** Use `surface_container_high` (#222a3d) or `highest` (#2d3449) for cards and modals that need to feel closer to the user.

### The "No-Line" Rule
**Explicit Instruction:** You are prohibited from using 1px solid borders for sectioning or layout divisions. To separate a sidebar from a main content area, or a header from a body, use a background color shift (e.g., `surface_container_low` transitioning to `surface`). Boundaries are felt through tonal contrast, not drawn with lines.

### The "Glass & Gradient" Rule
To elevate the UI beyond standard Tailwind defaults:
- **Glassmorphism:** For floating menus or popovers, use `surface_bright` at 60% opacity with a `backdrop-blur-md` (12px-16px).
- **Signature Textures:** Main CTAs should not be flat. Apply a subtle linear gradient from `primary` (#c0c1ff) to `primary_container` (#8083ff) at a 135-degree angle to give buttons a "gem-like" tactile quality.

---

## 3. Typography

The typographic system is a dialogue between human-centric geometric sans-serifs and technical monospaced fonts.

- **Display & Headlines (Manrope):** These are your "Editorial" voices. Use `display-lg` and `headline-md` with slightly tighter letter-spacing (-0.02em) to create an authoritative, premium look.
- **UI & Body (Inter):** The "Workhorse." Used for all functional labels and reading text. Use `body-md` (0.875rem) as your default to maintain high data density.
- **Technical Data (JetBrains Mono):** This is non-negotiable for IDs, transaction hashes, code snippets, and billing amounts. It signals precision and "under-the-hood" transparency.

---

## 4. Elevation & Depth

In this system, depth is a result of light physics, not CSS tricks.

### The Layering Principle
Stack your surfaces. A `surface_container_highest` card sitting on a `surface_container_low` background creates a natural, soft lift. This "tonal stacking" is more modern and less cluttered than traditional drop shadows.

### Ambient Shadows
When a component must float (e.g., a Modal or a Command Palette), use **Ambient Shadows**:
- **Color:** Use a tinted shadow based on `surface_container_lowest` at 40% opacity.
- **Spread:** Large blur (32px to 64px) with zero spread. This mimics a soft, environmental glow rather than a harsh "drop shadow."

### The "Ghost Border" Fallback
If a border is required for accessibility (e.g., in high-contrast needs), use a **Ghost Border**. This is a 1px stroke using `outline_variant` at 10-20% opacity. Never use 100% opaque borders for decorative containment.

---

## 5. Components

### Buttons
- **Primary:** Gradient from `primary` to `primary_container`. 6px (`md`) radius. Text is `on_primary_fixed`.
- **Secondary:** Surface-based with a `Ghost Border`. 
- **Tertiary:** No background. Use `primary` color for text with an underline on hover.
- **States:** On `:active`, the gradient should invert or darken by 10%.

### Input Fields
- **Base:** `surface_container_highest` background. 4px (`sm`) radius. 
- **Focus:** 1px `primary` border. No "glow" or heavy rings.
- **Labels:** Always use `label-md` in `on_surface_variant`. 

### Cards & Lists
- **The Divider Rule:** Forbid the use of divider lines between list items. Use 12px (`3.5`) vertical spacing and a `surface` hover state to indicate individual rows.
- **Radius:** Strictly 8px (`lg`) for cards.

### Chips & Badges
- **Usage/Billing:** Use `secondary` (#ffb95f) for usage-related chips to draw the eye to "cost" and "limits" without the alarm of an "error" red.
- **Status:** Use low-saturation variants of `primary` for active states.

---

## 6. Do's and Don'ts

### Do
- **Embrace Density:** Use the 8px grid to pack information tightly. The "Midnight Architect" loves precision.
- **Use Intentional Asymmetry:** If a dashboard has three widgets, make one 2/3 width and the others 1/3. It feels more "designed" and less like a template.
- **Prioritize Mono for Numbers:** Always use JetBrains Mono for monetary values and data counts.

### Don't
- **Don't use #000000:** Pure black kills the depth of the deep navy `surface`. 
- **Don't use standard shadows:** If you find yourself reaching for `shadow-lg`, stop and use a background color shift instead.
- **Don't use 100% white text:** Use `on_surface` (#dae2fd). It is a soft, tinted white that reduces eye strain in dark-first environments.
- **Don't use dividers:** If you need to separate content, use the Spacing Scale (e.g., `space-y-4`) or a background color shift. 