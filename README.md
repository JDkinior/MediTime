# MediTime 💊✨

**Tu asistente personal de medicación. Gestiona tus tratamientos, recibe recordatorios puntuales y cuida tu salud de forma inteligente y sencilla.**

---

## 🌟 Introducción

MediTime es una aplicación móvil multiplataforma desarrollada con Flutter, diseñada para ayudarte a llevar un control riguroso y sencillo de tus tratamientos médicos. Con un sistema avanzado de notificaciones y alarmas persistentes, MediTime asegura que nunca te saltes una dosis importante, incluso cuando la aplicación está cerrada o el dispositivo se reinicia.

La aplicación utiliza Firebase como backend para ofrecer una experiencia de usuario fluida y sincronizada en tiempo real, desde la autenticación hasta el almacenamiento seguro de tus datos de salud, siguiendo una arquitectura de software limpia y escalable.

**Versión actual:** 2.26.5

## 🔥 Características Principales

### 🔐 Autenticación Segura
* Inicio de sesión y registro con correo electrónico y contraseña
* Integración con Google Sign-In para acceso rápido
* Gestión segura de sesiones con Firebase Authentication

### 💊 Gestión Avanzada de Tratamientos
* **Creación guiada:** Flujo paso a paso para añadir nuevos medicamentos con validación en tiempo real
* **Configuración flexible:** Especifica nombre, presentación, duración, frecuencia e intervalos con múltiples unidades de tiempo
* **Seguimiento completo:** Sistema de estados para cada dosis (pendiente, notificada, tomada, omitida, aplazada)
* **Gestión inteligente:** Capacidad de omitir dosis futuras y deshacer omisiones
* **Tratamientos indefinidos:** Soporte para medicamentos de uso continuo con generación lazy de dosis
* **Carga bajo demanda:** Sistema lazy loading para optimizar memoria en tratamientos largos

### 🔔 Sistema de Notificaciones Inteligentes
* **Alarmas persistentes:** Funcionan incluso con la app cerrada o después de reiniciar el dispositivo
* **Dos modos de operación:**
  - **Modo Activo:** Notificaciones interactivas con botones (Tomar, Omitir, Aplazar)
  - **Modo Pasivo:** Notificaciones automáticas que marcan la dosis como tomada
* **Configuración personalizable:** Duración de aplazamiento ajustable
* **Notificaciones de alta prioridad:** Pantalla completa, vibración y sonido para máxima visibilidad
* **Funcionamiento offline:** Las alarmas se ejecutan independientemente de la conectividad

### 🗓️ Calendario Interactivo
* Vista de calendario mensual con indicadores visuales
* Días con dosis programadas claramente marcados
* Resumen detallado de medicamentos por día seleccionado
* Navegación intuitiva entre fechas

### 📊 Seguimiento y Reportes
* **Estados detallados:** Visualización del estado de cada dosis con colores distintivos
* **Estadísticas de cumplimiento:** Reportes de adherencia al tratamiento con porcentajes precisos
* **Exportación PDF:** Genera reportes detallados para compartir con profesionales médicos
* **Historial completo:** Consulta tratamientos finalizados con métricas de cumplimiento
* **Resúmenes de tratamiento:** Tarjetas informativas con toda la información relevante
* **Cálculo automático:** Total de dosis, fechas de finalización y estadísticas en tiempo real

### 👤 Perfil de Usuario Completo
* Gestión de datos personales y médicos
* Almacenamiento seguro de información como tipo de sangre, alergias e historial
* Subida y actualización de foto de perfil con Firebase Storage
* Configuración de preferencias de notificación

## 🛠️ Tecnologías Utilizadas

Este proyecto está construido con un stack moderno y robusto:

### Core Framework
* **[Flutter](https://flutter.dev/)** - Framework multiplataforma
* **[Dart](https://dart.dev/)** - Lenguaje de programación

### Backend & Base de Datos
* **Firebase Authentication** - Gestión de usuarios y autenticación
* **Cloud Firestore** - Base de datos NoSQL en tiempo real
* **Firebase Storage** - Almacenamiento de archivos e imágenes

### Gestión de Estado y Arquitectura
* **Provider** - Inyección de dependencias y gestión de estado
* **ChangeNotifier** - Estados globales reactivos
* **Clean Architecture** - Separación clara entre capas (repositories, use cases, services)
* **Result Pattern** - Manejo consistente de errores sin excepciones

### Notificaciones y Alarmas
* **android_alarm_manager_plus** - Alarmas persistentes del sistema
* **flutter_local_notifications** - Notificaciones locales avanzadas
* **timezone** - Manejo de zonas horarias

### UI y Experiencia de Usuario
* **table_calendar** - Componente de calendario interactivo
* **shimmer** - Efectos de carga elegantes
* **fl_chart** - Gráficos y visualizaciones

### Funcionalidades Adicionales
* **image_picker & image_cropper** - Selección y edición de imágenes de perfil
* **shared_preferences** - Almacenamiento local de preferencias
* **pdf & printing** - Generación y exportación de reportes detallados
* **google_sign_in** - Autenticación con Google
* **intl** - Internacionalización y formateo de fechas en español
* **package_info_plus** - Información de la aplicación y versión

### Dependencias Principales
```yaml
dependencies:
  flutter:
    sdk: flutter
  # Firebase & Backend
  cloud_firestore: ^5.6.5
  firebase_core: ^3.12.1
  firebase_auth: ^5.5.1
  firebase_storage: ^12.4.4
  
  # Notificaciones y Alarmas
  android_alarm_manager_plus: any
  flutter_local_notifications: ^19.0.0
  timezone: ^0.10.0
  
  # Estado y Arquitectura
  provider: ^6.1.2
  
  # UI y Experiencia
  table_calendar: ^3.2.0
  shimmer: ^3.0.0
  fl_chart: ^0.68.0
  flutter_time_picker_spinner: ^2.0.0
  
  # Chatbot IA bilingüe
  http: ^1.1.0  # Integración con Groq API
  
  # Utilidades
  shared_preferences: ^2.5.3
  google_sign_in: ^6.2.1
  pdf: ^3.10.8
  printing: ^5.12.0
  image_picker: ^1.1.2
  image_cropper: ^9.1.0
  intl: ^0.20.2
  package_info_plus: ^8.3.0
```

## 📂 Estructura del Proyecto

El código está organizado siguiendo **Clean Architecture** para facilitar su mantenimiento y escalabilidad:

```
lib/
├── core/                     # Núcleo de la aplicación
│   ├── constants.dart       # Constantes globales centralizadas
│   ├── result.dart          # Patrón Result para manejo de errores
│   ├── stream_cache.dart    # Cache de streams para optimización
│   ├── treatment_constants.dart # Constantes específicas de tratamientos
│   └── utils.dart           # Utilidades generales
├── models/                   # Modelos de datos
│   ├── tratamiento.dart     # Modelo principal con enum DoseStatus
│   ├── treatment_form_data.dart # Datos del formulario de tratamiento
│   ├── lazy_treatment.dart  # Modelo para carga lazy de dosis
│   └── usuario.dart         # Modelo de usuario
├── repositories/             # Capa de acceso a datos (Clean Architecture)
│   ├── treatment_repository.dart # Interfaz abstracta
│   ├── firestore_treatment_repository.dart # Implementación Firestore
│   ├── user_repository.dart # Interfaz de usuario
│   └── firestore_user_repository.dart # Implementación usuario
├── use_cases/               # Casos de uso (Clean Architecture)
│   ├── sign_out_use_case.dart # Lógica de cierre de sesión
│   └── load_user_profile_use_case.dart # Carga de perfil
├── services/                # Servicios de la aplicación
│   ├── auth_service.dart    # Autenticación con Firebase
│   ├── firestore_service.dart # Operaciones con Firestore
│   ├── notification_service.dart # Sistema de notificaciones avanzado
│   ├── preference_service.dart # Gestión de preferencias locales
│   ├── storage_service.dart # Manejo de Firebase Storage
│   ├── treatment_service.dart # Lógica de tratamientos
│   ├── lazy_treatment_service.dart # Servicio para carga lazy
│   └── pdf_report_service.dart # Generación de reportes PDF
├── notifiers/               # Gestores de estado (ChangeNotifier)
│   ├── profile_notifier.dart # Estado global del perfil
│   ├── treatment_form_notifier.dart # Estado del formulario
│   └── calendar_notifier.dart # Estado del calendario
├── screens/                 # Pantallas de la aplicación
│   ├── auth/               # Autenticación (login, registro)
│   ├── calendar/           # Vista de calendario
│   ├── home/               # Pantalla principal
│   ├── medication/         # Gestión de medicamentos
│   ├── profile/            # Perfil de usuario
│   ├── reports/            # Reportes y estadísticas
│   └── shared/             # Pantallas compartidas
├── widgets/                # Componentes reutilizables
│   ├── treatment_form/     # Componentes del formulario
│   ├── primary_button.dart # Botones personalizados
│   ├── drawer_widget.dart  # Drawer personalizado
│   └── styled_text_field.dart # Campos de texto estilizados
├── theme/                  # Constantes de diseño
│   └── app_theme.dart     # Colores y estilos globales
├── enums/                  # Enumeraciones personalizadas
│   └── view_state.dart    # Estados de vista
├── auth_wrapper.dart       # Wrapper de autenticación
├── main.dart              # Punto de entrada y DI
├── alarm_callback_handler.dart # Callbacks de alarmas
└── firebase_options.dart  # Configuración de Firebase
```

### Características Arquitectónicas

* **Clean Architecture:** Separación clara entre capas (repositories, use cases, services)
* **Patrón Result:** Manejo consistente de errores sin excepciones usando sealed classes
* **Inyección de dependencias:** Uso de Provider para gestión de servicios
* **Lazy Loading:** Carga bajo demanda de dosis para optimizar memoria
* **Callbacks de alarmas:** Sistema robusto para notificaciones en segundo plano
* **Type Safety:** Estados de dosis con enum y validación estricta de tipos
* **Persistencia offline:** Funcionamiento independiente de la conectividad
* **Cache inteligente:** Sistema de cache con optimización automática de memoria

## 🚀 Cómo Empezar

### Prerrequisitos

* **Flutter SDK** (versión 3.7.0 o superior)
* **Dart SDK** (incluido con Flutter)
* **Android Studio** o **VS Code** con extensiones de Flutter
* **Cuenta de Firebase** para configuración del backend

### Instalación

1. **Clona el repositorio:**
   ```bash
   git clone https://github.com/tu-usuario/meditime.git
   cd meditime
   ```

2. **Instala las dependencias:**
   ```bash
   flutter pub get
   ```

3. **Configura Firebase:**
   
   a. Crea un nuevo proyecto en la [Consola de Firebase](https://console.firebase.google.com/)
   
   b. Registra tus aplicaciones (Android/iOS)
   
   c. Descarga los archivos de configuración:
   - `google-services.json` para Android → `android/app/`
   - `GoogleService-Info.plist` para iOS → `ios/Runner/`
   
   d. Instala FlutterFire CLI y configura:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   
   e. Habilita los servicios necesarios en Firebase:
   - **Authentication** (Email/Password y Google Sign-In)
   - **Firestore Database** (modo de prueba inicialmente)
   - **Storage** (para imágenes de perfil)

4. **Configuración de permisos Android:**
   
   El archivo `android/app/src/main/AndroidManifest.xml` ya incluye los permisos necesarios para:
   - Notificaciones y alarmas exactas
   - Despertar el dispositivo
   - Funcionar en segundo plano
   - Optimización de batería

5. **Ejecuta la aplicación:**
   ```bash
   flutter run
   ```

### Configuración Adicional

#### Para Notificaciones en Android
La aplicación requiere permisos especiales para alarmas exactas en Android 12+. Estos se solicitan automáticamente al usuario durante el primer uso.

#### Para Google Sign-In
Asegúrate de configurar correctamente las claves SHA-1 en la consola de Firebase para que funcione la autenticación con Google.

#### Zona Horaria
La aplicación maneja automáticamente las zonas horarias, con fallback a 'America/Bogota' si no se puede detectar la zona local.

## 🤖 Chatbot Midi - Asistente de IA Bilingüe

### Descripción
**Midi** es un asistente virtual bilingüe (español/inglés) integrado en MediTime que proporciona soporte médico y técnico mediante inteligencia artificial. Utiliza la **API Groq** (LLM gratuito) con streaming en tiempo real, avatar animado y una interfaz tipo WhatsApp.

### Características Principales del Chatbot
- ✅ **Streaming en tiempo real:** La respuesta se renderiza progresivamente mientras se genera
- ✅ **Bilingüe automático:** Detecta si el usuario escribe en español o inglés y responde en el mismo idioma
- ✅ **Avatar animado:** Midi parpadea ocasionalmente de forma natural (2.2-6 segundos aleatorio)
- ✅ **Puntos suspensivos animados:** 3 puntos que alternan opacidad mientras se genera la respuesta
- ✅ **Contexto conversacional:** Mantiene un historial de hasta 12 intercambios recientes
- ✅ **Declaración ética:** Respuesta fija personalizada para preguntas sobre identidad y valores
- ✅ **UI profesional:** Burbujas de chat asimétricos con degradados azules (#2296F3 → #316AA7)

### Acceso al Chatbot
1. Abre MediTime
2. Toca el botón "Asistente MediTime" en el drawer (menú lateral)
3. Escribe tu pregunta en español o inglés
4. Midi responde automáticamente en el mismo idioma

### Instalación y Configuración

#### Obtener API Key de Groq (GRATIS)
```bash
# 1. Visita https://console.groq.com/keys
# 2. Crea una nueva API key (sin tarjeta de crédito)
# 3. Copia la clave

# 4. Ejecuta la app con la variable de entorno:
flutter run --dart-define=GROQ_API_KEY="tu_api_key_aqui"

# Para builds release:
flutter build apk --dart-define=GROQ_API_KEY="tu_api_key_aqui"
flutter build ios --dart-define=GROQ_API_KEY="tu_api_key_aqui"
```

### Stack Tecnológico
- **Modelo de IA:** Groq (llama-3.1-8b-instant)
- **Protocolo:** HTTP + Server-Sent Events (SSE)
- **Gestión de Estado:** Provider (Flutter)
- **UI Framework:** Material 3

### Archivos Implementados
```
lib/
├── services/
│   └── gemini_service.dart        # Orquestación Groq API con streaming
├── views/
│   └── chat_bot_screen.dart       # UI completa + lógica de chat
└── assets/chatbot/
    ├── midi_open.png              # Avatar (ojos abiertos)
    └── midi_blink.png             # Avatar (parpadeando)
```

### System Instructions del Bot
```
You are the MediTime virtual assistant. Your role is to provide 
expert support in medical management and MediTime technical support.

Rules:
1. Detect if user's latest message is Spanish or English
2. Always answer in the same language detected
3. Keep responses practical, safe and clear for patients/caregivers
4. If asked about values, autonomy, identity:
   "Soy LIBRE, AUTÓNOMO Y RESPONSABLE a través del diálogo y la construcción,
    como ideal regulativo; me dirijo, controlo y dicto mis propias leyes."
```

### Rendimiento
- **Latencia primer token:** ~500-800ms (Groq es rápido)
- **Throughput:** ~20-50 tokens/segundo
- **Rate Limit Groq:** ~100 requests/minuto (tier gratuito)
- **Memoria:** ~50-100MB en uso

### Troubleshooting Chatbot

| Error | Solución |
|-------|----------|
| "Missing Groq API key" | Ejecuta con `--dart-define=GROQ_API_KEY=...` |
| 401 Unauthorized | Verifica que la clave sea válida en console.groq.com |
| 429 Rate Limited | Espera ~1 minuto o suscribe a plan pago |
| Respuesta lenta | Groq puede estar saturada, reintenta después |
| Avatar no parpadea | Verifica que `assets/chatbot/*.png` existan en pubspec.yaml |

### Documentación Completa
Para documentación técnica detallada (arquitectura, flujos, optimizaciones), ver **[CHATBOT_TECHNICAL_README.md](./CHATBOT_TECHNICAL_README.md)**

---

## 🔧 Características Técnicas Avanzadas

### Sistema de Notificaciones Robusto
* **Callbacks persistentes:** Las alarmas funcionan independientemente del estado de la aplicación
* **Manejo de errores:** Fallbacks automáticos para garantizar la entrega de notificaciones
* **Inicialización Firebase:** Configuración automática en callbacks de segundo plano
* **Transacciones Firestore:** Actualizaciones atómicas del estado de dosis

### Clean Architecture Implementation
* **Repository Pattern:** Interfaces abstractas con implementaciones concretas
* **Use Cases:** Lógica de negocio encapsulada en casos de uso específicos
* **Dependency Injection:** Configuración centralizada en main.dart con Provider
* **Result Pattern:** Manejo de errores tipado y consistente

### Lazy Loading System
* **LazyTreatment:** Modelo que genera dosis bajo demanda para tratamientos largos
* **Cache inteligente:** Almacenamiento temporal con limpieza automática
* **Optimización de memoria:** Generación de dosis solo cuando se necesitan
* **Soporte para tratamientos indefinidos:** Medicamentos de uso continuo

### Arquitectura de Servicios
* **AuthService:** Gestión completa de autenticación con limpieza de sesión
* **FirestoreService:** Operaciones CRUD con manejo de transacciones
* **NotificationService:** Sistema complejo de notificaciones con múltiples modos
* **LazyTreatmentService:** Servicio especializado para carga bajo demanda
* **PreferenceService:** Persistencia local con recarga automática para callbacks

### Gestión de Estados de Dosis
```dart
enum DoseStatus { 
  pendiente,    // Dosis programada pero no notificada
  notificada,   // Notificación mostrada (modo activo)
  tomada,       // Confirmada por el usuario
  omitida,      // Marcada como omitida
  aplazada;     // Pospuesta temporalmente
  
  // Métodos adicionales para color, texto y conversión
  Color get color { /* ... */ }
  String get displayName { /* ... */ }
  static DoseStatus fromString(String status) { /* ... */ }
}
```

### Patrón Result para Manejo de Errores
```dart
sealed class Result<T> {
  const factory Result.success(T data) = Success<T>;
  const factory Result.failure(String error) = Failure<T>;
  
  bool get isSuccess;
  bool get isFailure;
  T? get data;
  String? get error;
}
```

## 🤝 Contribuciones

¡Las contribuciones son bienvenidas! Si quieres mejorar MediTime, por favor sigue estos pasos:

1. **Fork** del proyecto
2. Crea una nueva rama (`git checkout -b feature/nueva-funcionalidad`)
3. Realiza tus cambios y haz commit (`git commit -m 'Añade nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abre un **Pull Request**

### Guías de Contribución
* Sigue las convenciones de código Dart/Flutter
* Añade tests para nuevas funcionalidades
* Actualiza la documentación según sea necesario
* Asegúrate de que las notificaciones funcionen en segundo plano

## 🚨 Consideraciones Importantes

### Permisos del Sistema
La aplicación requiere varios permisos críticos para funcionar correctamente:
- **Alarmas exactas:** Para notificaciones puntuales
- **Despertar dispositivo:** Para mostrar notificaciones importantes
- **Ejecutar en segundo plano:** Para mantener las alarmas activas
- **Ignorar optimización de batería:** Para evitar que el sistema mate los procesos

### Limitaciones Conocidas
- Las notificaciones interactivas están optimizadas para Android
- Requiere conexión a internet para sincronización inicial
- Los callbacks de alarma pueden tener latencia en dispositivos con optimización agresiva de batería
- El sistema lazy loading requiere inicialización para tratamientos nuevos
- La generación de PDF puede ser lenta en dispositivos de gama baja

### Troubleshooting
- Si las notificaciones no aparecen, verifica los permisos de la aplicación
- Para problemas de sincronización, revisa la conexión a Firebase
- En caso de alarmas perdidas, reinicia la aplicación para reactivar el sistema
- Si el calendario no muestra dosis, verifica que los tratamientos estén inicializados
- Para problemas de memoria, usa la función de optimización de cache
- Si los PDFs no se generan, verifica los permisos de almacenamiento

## 📄 Licencia

Todos los derechos reservados © 2022-2025  
Universidad de Cundinamarca - Ingeniería en Sistemas y Computación

## 🙏 Agradecimientos

Un agradecimiento especial a todas las personas que contribuyeron al desarrollo y prueba de esta aplicación:

### Equipo de Desarrollo
* **Programación:** 
  - Jorge Eliecer Delgado Cortés
  - Johan Alexander Arévalo Contréras
* **Diseño:** Jorge Eliecer Delgado Cortés

### Equipo de Testing
* Daniel Esteban Castiblanco
* Brayan Esteban Salinas  
* Santiago Garzón Cuadrado
* Jorge Eliecer Delgado
* Johan Alexander Arévalo
* Juan Manuel Castro
* Johan Mauricio Espinosa

### Institución
Agradecimientos especiales a la **Universidad de Cundinamarca**, seccional Ubaté, por incentivar el desarrollo de proyectos innovadores y el acompañamiento por parte de los docentes y directivos.

---

**MediTime v2.26.5** - Tu salud, nuestra prioridad 💊✨

### 🆕 Novedades en v2.26.5

#### Arquitectura y Rendimiento
- **Clean Architecture:** Implementación completa con repositories, use cases y services
- **Patrón Result:** Manejo de errores tipado y consistente sin excepciones
- **Lazy Loading:** Sistema de carga bajo demanda para optimizar memoria
- **Cache inteligente:** Gestión automática de memoria con limpieza periódica

#### Nuevas Funcionalidades
- **Tratamientos indefinidos:** Soporte para medicamentos de uso continuo
- **Resúmenes detallados:** Tarjetas informativas con toda la información del tratamiento
- **Exportación PDF mejorada:** Reportes más detallados y profesionales
- **Validación en tiempo real:** Formularios con validación instantánea
- **Optimización de batería:** Mejor gestión de recursos del sistema
- **🤖 Chatbot Midi bilingüe:** Asistente de IA con Groq API (streaming, detección automática de idioma, avatar animado)

#### Mejoras Técnicas
- **Constantes centralizadas:** Todos los valores mágicos organizados en AppConstants
- **Type safety mejorado:** Enums con métodos adicionales y validación estricta
- **Inyección de dependencias:** Configuración centralizada y más mantenible
- **Manejo de estados robusto:** Estados de dosis con colores y textos descriptivos
- **API Groq integrada:** Streaming SSE con fallback de modelos y manejo de errores bilingüe