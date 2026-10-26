# Guía de Desarrollo y Diseño UI/UX - MediTime

## 1. Principios de Diseño UI/UX (Filosofía Emil Kowalski aplicada a Flutter)
- **Material 3 & Coherencia Visual**: Utiliza componentes de Material Design 3 con paleta de colores coherente, bordes suaves (rounded corners) y espaciados estándar (múltiplos de 4 u 8 pt).
- **Diseño Minimalista y Moderno**: Evita sobrecargar pantallas de salud y medicamentos. La legibilidad, jerarquía tipográfica y accesibilidad (contraste de texto, soporte para fuentes grandes) son críticas.
- **Física y Micro-interacciones (Apple-style & Emil Kowalski Craft)**:
  - Transiciones suaves y naturales con curvas spring/físicas (`Curves.easeOutCubic`, `Curves.fastOutSlowIn` o `SpringSimulation`).
  - Handoff de gestos interrumpibles (swipe para descartar dosis, sheets deslizables con arrastre fluido).
  - Feedback táctil (`HapticFeedback.lightImpact()`) y visual inmediato al interactuar con recordatorios o completar tomas.
  - No animar por animar; cada transición debe orientar al usuario en el espacio.
- **Diseño Responsivo**: Emplea `LayoutBuilder`, `MediaQuery` o flex widgets para asegurar adaptación impecable en pantallas pequeñas, tablets y diferentes relaciones de aspecto.
- **Robustez ante Datos Extremos (Break UI)**: Diseña cada widget pensando en nombres de medicamentos largos, dosis inusuales, listas vacías y pantallas con modo oscuro activo.

## 2. Buenas Prácticas en Flutter & Dart
- **Arquitectura Limpia**: Separación clara entre capas de UI (Screens & Widgets), lógica de estado (Bloc / Provider / Riverpod) y servicios de datos / repositorios.
- **Inmutabilidad y Performance**: Declara widgets `const` siempre que sea posible para optimizar el árbol de widgets y evitar rebuilds innecesarios.
- **Seguridad de Tipos**: Usa Null Safety estricto y tipado explícito en modelos y métodos de servicio.
- **Firebase & Firestore**: Estructuración eficiente de colecciones y consultas, evitando lecturas redundantes y respetando las reglas de seguridad de Firestore.
