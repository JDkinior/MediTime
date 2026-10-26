# MediTime Agent Guidelines & Design Engineering Standards

This project adheres to the **Emil Kowalski Design Engineering & Animation Philosophy** to build interfaces with exceptional craft, fluid motion, and high aesthetic taste.

---

## 🎨 Design Engineering Principles (Emil Kowalski)

When designing, building, or reviewing UI components, screens, or animations in MediTime:

### 1. Motion & Micro-Interactions
* **Speed & Responsiveness:** Interactive feedback animations should be fast and snappy—generally between **150ms and 280ms**.
* **Proper Easing:** 
  * Entrances must **never** use `Curves.easeIn`. Use `Curves.easeOut`, `Curves.easeOutCubic`, or `Curves.fastOutSlowIn` so the user receives immediate visual feedback.
  * Exits should be quick and discreet.
* **No `scale(0)` Entrances:** Nothing in nature emerges from absolute nothingness. When animating cards, dialogs, or bottom sheets into view, scale up from `0.90 - 0.95` combined with an opacity fade (`0 -> 1`), rather than popping out from 0.
* **Origins Matter:** Modals and center dialogs scale from center, but popovers, context menus, and tooltips should scale from their trigger point.

### 2. Tactile Mobile Experience
* **Touch Feedback:** Every interactive element (buttons, dose cards, switches) must provide immediate visual feedback on press (e.g., subtle scale down to `0.97` or subtle background shift) and light haptic feedback where appropriate (`HapticFeedback.lightImpact()`).
* **Hit Targets:** Minimum touch targets of 44x44 or 48x48 pt.
* **Visual Polish:** Favor soft, layered shadows and elevation over harsh, solid 1px borders.
* **Mobile Native Feel:** Respect `SafeArea`, handle notches, status bars, keyboard avoidance, and overscroll bounces cleanly.

### 3. Performance & Frame Budget
* Maintain 60/120 FPS.
* Use `RepaintBoundary` on animated subtrees to isolate repaint regions.
* Drive transitions using `AnimatedBuilder` or specialized Flutter transition widgets (`ScaleTransition`, `FadeTransition`, `SlideTransition`) instead of rebuilding heavy widget trees inside `setState`.

---

## 🛠️ Available Design Skills

The following specialized Emil Kowalski skills are installed and available for this workspace:
* **`emil-design-eng`**: Core UI craft, component polish, and invisible details.
* **`animate`**: Building fluid animations and micro-interactions from scratch.
* **`review-animations`**: Strict review of existing motion against the craft bar (Before/After analysis).
* **`improve-animations`**: Codebase-wide motion audits and prioritized implementation plans.
* **`find-animation-opportunities`**: Discovering where subtle motion elevates user experience.
* **`apple-design`**: Fluid physical motion, spring curves, sheets, and translucent depth.
* **`mobile-native`**: Mobile-specific touch polish, scroll ergonomics, and layout ergonomics.
* **`animation-performance`**: Avoiding jank, keeping motion off the main UI thread.
* **`break-ui`**: Stress-testing UI with extreme data (long medication names, edge case schedules, empty states).
* **`prototype`**: Generating fast UI alternatives and design variations.
