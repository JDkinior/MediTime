# Normas de Desarrollo Web - MediTime Page

## 1. Diseño y Estética Web
- **Diseño Moderno y Responsivo**: Mantener la estética limpia de la marca MediTime (landing page médica/tecnológica). Uso de CSS variables, Grid y Flexbox.
- **Tipografía y Jerarquía**: Fuentes legibles, espaciados generosos y contraste accesible (WCAG AA mínimo).
- **Animaciones Suaves**: Micro-interacciones con `transition` y `animation` CSS optimizadas con `transform` y `opacity` para garantizar 60 fps.

## 2. Código Frontend (Vanilla Web & PWA)
- **HTML Semántico**: Uso correcto de `<header>`, `<main>`, `<section>`, `<article>`, `<nav>`, `<footer>`.
- **Service Worker & PWA**: Respetar la estrategia de caché en `sw.js` y el manifiesto `manifest.webmanifest`.
- **Rendimiento**: Minimizar re-renders en JavaScript, evitar dependencias pesadas y cargar recursos multimedia de manera diferida (`loading="lazy"`).
