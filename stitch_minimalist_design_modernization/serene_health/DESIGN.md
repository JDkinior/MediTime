---
name: Serene Health
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#434655'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#737686'
  outline-variant: '#c3c6d7'
  surface-tint: '#0053db'
  primary: '#004ac6'
  on-primary: '#ffffff'
  primary-container: '#2563eb'
  on-primary-container: '#eeefff'
  inverse-primary: '#b4c5ff'
  secondary: '#006c49'
  on-secondary: '#ffffff'
  secondary-container: '#6cf8bb'
  on-secondary-container: '#00714d'
  tertiary: '#784b00'
  on-tertiary: '#ffffff'
  tertiary-container: '#996100'
  on-tertiary-container: '#ffeedd'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dbe1ff'
  primary-fixed-dim: '#b4c5ff'
  on-primary-fixed: '#00174b'
  on-primary-fixed-variant: '#003ea8'
  secondary-fixed: '#6ffbbe'
  secondary-fixed-dim: '#4edea3'
  on-secondary-fixed: '#002113'
  on-secondary-fixed-variant: '#005236'
  tertiary-fixed: '#ffddb8'
  tertiary-fixed-dim: '#ffb95f'
  on-tertiary-fixed: '#2a1700'
  on-tertiary-fixed-variant: '#653e00'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
typography:
  headline-lg:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 30px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  gutter: 16px
  margin-mobile: 20px
  margin-desktop: 40px
---

## Brand & Style

The design system is centered on the concept of "Clinical Warmth." It bridges the gap between medical precision and human empathy. The target audience includes patients managing chronic conditions and wellness-conscious individuals who require a low-friction, high-reliability interface.

The visual style is **Modern Corporate Minimalism**. It utilizes a "soft-layering" approach where depth is communicated through subtle tonal changes and soft-edged containers rather than aggressive shadows. The interface prioritizes high-legibility typography and purposeful whitespace to reduce cognitive load, fostering an emotional response of calm, control, and efficiency.

## Colors

The palette is anchored by a **Professional Blue** (Primary) which signifies trust and stability. 

- **Primary:** Used for active states, primary actions, and key progress indicators.
- **Success (Green):** Specifically for "Taken" medication states and positive health milestones.
- **Warning/Error (Amber/Red):** Used sparingly for missed doses or critical health alerts.
- **Neutrals:** A scale of Slate Grays is used to establish hierarchy. The background is a very soft off-white to reduce screen glare, while surfaces remain pure white to provide maximum contrast for content.

## Typography

This design system utilizes **Inter** for its exceptional legibility in data-heavy contexts. The hierarchy is strictly enforced through weight distinctions: 

- **Headlines:** Use Bold (700) or SemiBold (600) to anchor sections.
- **Body:** Uses Regular (400) for high readability in instructions and descriptions.
- **Labels:** Use SemiBold (600) at smaller sizes for metadata and status chips.

Line heights are generous to prevent visual "crowding," which is essential for elderly users or those in stressful health situations.

## Layout & Spacing

The design system employs a **Fluid Grid** model with a base unit of 4px. 

- **Mobile:** Uses a single-column layout with 20px side margins. Cards span the full width minus margins.
- **Desktop:** Utilizes a 12-column grid. Information is grouped into focused "modules" or "widgets" to prevent lines of text from becoming too long (max-width 680px for readable content).

Gaps between related elements (like a label and an input) should be 8px (sm), while gaps between distinct sections should be 32px (xl) to create clear breathing room.

## Elevation & Depth

Visual hierarchy is achieved through **Tonal Layers** and **Ambient Shadows**. 

1.  **Level 0 (Background):** Slate-50 (#F8FAFC).
2.  **Level 1 (Cards/Containers):** Pure White (#FFFFFF) with a very soft, diffused shadow (Blur: 15px, Y: 4px, Color: 4% Black) and a subtle 1px border in Slate-100.
3.  **Level 2 (Modals/Popovers):** Pure White with a more pronounced shadow (Blur: 30px, Y: 10px, Color: 8% Black).

Avoid heavy dropshadows or inner shadows. The goal is to make elements appear as if they are resting gently on the surface rather than floating high above it.

## Shapes

The shape language is defined by **Rounded** corners to evoke friendliness and safety. 

- **Standard Containers:** Use `rounded-lg` (16px) for cards and main UI blocks.
- **Interactive Elements:** Buttons and input fields use `rounded-md` (8px to 12px) for a slightly more precise, functional look.
- **Status Pills:** Use fully rounded (Pill) shapes for chips and status indicators to differentiate them from actionable buttons.

## Components

- **Buttons:** Primary buttons use solid Professional Blue with white text. Secondary buttons use a light blue ghost style or a subtle border. Corner radius should be 12px.
- **Chips/Status:** Used for medication status (e.g., "Taken", "Pending"). These should have high-contrast text on a very desaturated version of the background color (e.g., Green text on Light Green background).
- **Cards:** The primary container for information. Must include 16px of internal padding and a 16px corner radius. Subtle 1px border (#E2E8F0) is required to define edges against the light background.
- **Input Fields:** Large tap targets (minimum 48px height) with 12px corner radius. Labels must always be visible above the field, never just placeholder text.
- **Lists/Timelines:** Use a vertical "stem" for medication schedules. Completed items use the Success Green with a checkmark, while upcoming items use a hollow Neutral Slate circle.
- **Progress Rings:** For adherence tracking, use a circular gauge with a stroke width of 8px. Use the Primary Blue for the progress bar and a light gray for the remaining track.