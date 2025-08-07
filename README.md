# MediTime 💊✨

**Tu asistente personal de medicación. Gestiona tus tratamientos, recibe recordatorios puntuales y cuida tu salud de forma inteligente y sencilla.**

---

## 🌟 Introducción

MediTime es una aplicación móvil multiplataforma desarrollada con Flutter, diseñada para ayudarte a llevar un control riguroso y sencillo de tus tratamientos médicos. Con un sistema avanzado de notificaciones y alarmas persistentes, MediTime asegura que nunca te saltes una dosis importante, incluso cuando la aplicación está cerrada o el dispositivo se reinicia.

La aplicación utiliza Firebase como backend para ofrecer una experiencia de usuario fluida y sincronizada en tiempo real, desde la autenticación hasta el almacenamiento seguro de tus datos de salud, siguiendo una arquitectura de software limpia y escalable.

**Versión actual:** 2.25.2 alpha

## 🔥 Características Principales

### 🔐 Autenticación Segura
* Inicio de sesión y registro con correo electrónico y contraseña
* Integración con Google Sign-In para acceso rápido
* Gestión segura de sesiones con Firebase Authentication

### 💊 Gestión Avanzada de Tratamientos
* **Creación guiada:** Flujo paso a paso para añadir nuevos medicamentos
* **Configuración flexible:** Especifica nombre, presentación, duración, frecuencia e intervalos
* **Seguimiento completo:** Sistema de estados para cada dosis (pendiente, notificada, tomada, omitida, aplazada)
* **Gestión inteligente:** Capacidad de omitir dosis futuras y deshacer omisiones

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
* **Estados detallados:** Visualización del estado de cada dosis
* **Estadísticas de cumplimiento:** Reportes de adherencia al tratamiento
* **Exportación PDF:** Genera reportes para compartir con profesionales médicos
* **Historial completo:** Consulta tratamientos finalizados con métricas de cumplimiento

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

### Gestión de Estado
* **Provider** - Inyección de dependencias y gestión de estado
* **ChangeNotifier** - Estados globales reactivos

### Notificaciones y Alarmas
* **android_alarm_manager_plus** - Alarmas persistentes del sistema
* **flutter_local_notifications** - Notificaciones locales avanzadas
* **timezone** - Manejo de zonas horarias

### UI y Experiencia de Usuario
* **table_calendar** - Componente de calendario interactivo
* **shimmer** - Efectos de carga elegantes
* **fl_chart** - Gráficos y visualizaciones

### Funcionalidades Adicionales
* **image_picker** - Selección de imágenes
* **shared_preferences** - Almacenamiento local de preferencias
* **pdf & printing** - Generación y exportación de reportes
* **google_sign_in** - Autenticación con Google
* **intl** - Internacionalización y formateo de fechas

### Dependencias Principales
```yaml
dependencies:
  flutter:
    sdk: flutter
  cloud_firestore: ^5.6.5
  firebase_core: ^3.12.1
  firebase_auth: ^5.5.1
  android_alarm_manager_plus: any
  flutter_local_notifications: ^19.0.0
  provider: ^6.1.2
  shared_preferences: ^2.5.3
  table_calendar: ^3.2.0
  google_sign_in: ^6.2.1
  pdf: ^3.10.8
  printing: ^5.12.0
```

## 📂 Estructura del Proyecto

El código está organizado siguiendo una arquitectura limpia para facilitar su mantenimiento y escalabilidad:

```
lib/
├── models/                    # Modelos de datos
│   └── tratamiento.dart      # Modelo principal con enum DoseStatus
├── notifiers/                # Gestores de estado (ChangeNotifier)
│   └── profile_notifier.dart # Estado global del perfil de usuario
├── screens/                  # Pantallas de la aplicación
│   ├── auth/                # Autenticación (login, registro)
│   ├── calendar/            # Vista de calendario
│   ├── home/                # Pantalla principal
│   ├── shared/              # Pantallas compartidas (ayuda, configuración)
│   └── ...
├── services/                 # Lógica de negocio y servicios
│   ├── auth_service.dart    # Autenticación con Firebase
│   ├── firestore_service.dart # Operaciones con Firestore
│   ├── notification_service.dart # Sistema de notificaciones avanzado
│   ├── preference_service.dart # Gestión de preferencias locales
│   ├── storage_service.dart # Manejo de Firebase Storage
│   └── tratamiento_service.dart # Lógica de tratamientos
├── widgets/                  # Componentes reutilizables
│   └── primary_button.dart # Botones personalizados
├── theme/                    # Constantes de diseño
│   └── app_theme.dart       # Colores y estilos globales
├── enums/                    # Enumeraciones personalizadas
├── auth_wrapper.dart         # Wrapper de autenticación con inicialización
├── main.dart                # Punto de entrada y configuración de providers
├── alarm_callback_handler.dart # Lógica de callbacks de alarmas
└── firebase_options.dart    # Configuración de Firebase
```

### Características Arquitectónicas

* **Separación de responsabilidades:** Cada capa tiene una función específica
* **Inyección de dependencias:** Uso de Provider para gestión de servicios
* **Callbacks de alarmas:** Sistema robusto para notificaciones en segundo plano
* **Manejo de estados:** Estados de dosis con enum para type safety
* **Persistencia offline:** Funcionamiento independiente de la conectividad

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

## 🔧 Características Técnicas Avanzadas

### Sistema de Notificaciones Robusto
* **Callbacks persistentes:** Las alarmas funcionan independientemente del estado de la aplicación
* **Manejo de errores:** Fallbacks automáticos para garantizar la entrega de notificaciones
* **Inicialización Firebase:** Configuración automática en callbacks de segundo plano
* **Transacciones Firestore:** Actualizaciones atómicas del estado de dosis

### Arquitectura de Servicios
* **AuthService:** Gestión completa de autenticación con limpieza de sesión
* **FirestoreService:** Operaciones CRUD con manejo de transacciones
* **NotificationService:** Sistema complejo de notificaciones con múltiples modos
* **PreferenceService:** Persistencia local con recarga automática para callbacks

### Gestión de Estados de Dosis
```dart
enum DoseStatus { 
  pendiente,    // Dosis programada pero no notificada
  notificada,   // Notificación mostrada (modo activo)
  tomada,       // Confirmada por el usuario
  omitida,      // Marcada como omitida
  aplazada      // Pospuesta temporalmente
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

### Troubleshooting
- Si las notificaciones no aparecen, verifica los permisos de la aplicación
- Para problemas de sincronización, revisa la conexión a Firebase
- En caso de alarmas perdidas, reinicia la aplicación para reactivar el sistema

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

**MediTime v2.25.2 alpha** - Tu salud, nuestra prioridad 💊✨