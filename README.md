# MediTime 💊✨

**Tu asistente personal de medicación. Gestiona tus tratamientos, recibe recordatorios puntuales y cuida tu salud de forma inteligente y sencilla.**

---

## 🌟 Introducción

MediTime es una aplicación móvil multiplataforma, desarrollada con Flutter, diseñada para ayudarte a llevar un control riguroso y sencillo de tus tratamientos médicos. Olvídate de las confusiones y los olvidos; con MediTime, tendrás tus recetas, dosis y horarios siempre a la mano, asegurando que nunca te saltes una toma importante.

La aplicación utiliza Firebase como backend para ofrecer una experiencia de usuario fluida y sincronizada en tiempo real, desde la autenticación hasta el almacenamiento seguro de tus datos de salud, siguiendo una arquitectura de software limpia y escalable.

## 🔥 Características Principales

* **🔐 Autenticación Segura:** Inicio de sesión y registro con correo electrónico y contraseña, o mediante Google Sign-In, gestionado de forma segura con Firebase Authentication.
* **➕ Gestión de Tratamientos:**
    * Añade nuevos medicamentos a través de un flujo guiado paso a paso.
    * Especifica el nombre, presentación, duración del tratamiento, frecuencia y hora de la primera dosis.
    * Visualiza todas las dosis futuras agrupadas por fecha en una interfaz clara.
* **🔔 Notificaciones y Alarmas Inteligentes:**
    * Sistema de alarmas persistentes que funcionan incluso si la app está cerrada o el dispositivo se reinicia, gracias a `android_alarm_manager_plus`.
    * Notificaciones locales claras y puntuales para cada toma, con opciones de alta prioridad para asegurar su visibilidad.
* **🗓️ Calendario Interactivo:**
    * Visualiza todos tus tratamientos en una vista de calendario mensual.
    * Los días con dosis programadas se marcan visualmente para una referencia rápida.
    * Selecciona un día para ver un resumen detallado de los medicamentos correspondientes.
* **📊 Seguimiento y Reportes:**
    * Visualiza el detalle de las dosis para un día específico, con opción de marcarlas como "tomadas" u "omitidas".
    * Consulta un resumen completo de tratamientos finalizados, incluyendo estadísticas de cumplimiento.
    * Genera reportes de adherencia en PDF para compartir con tu médico.
* **👤 Perfil de Usuario Completo:**
    * Edita y almacena tus datos personales y médicos, como tipo de sangre, alergias e historial.
    * Sube y actualiza tu foto de perfil, almacenada de forma segura en Firebase Storage.

## 🛠️ Tecnologías Utilizadas

Este proyecto está construido con un stack moderno y robusto:

* **Framework:** [Flutter](https://flutter.dev/)
* **Lenguaje:** [Dart](https://dart.dev/)
* **Backend & Base de Datos:**
    * **Firebase Authentication:** Para la gestión de usuarios.
    * **Cloud Firestore:** Como base de datos NoSQL para almacenar los datos de usuarios y tratamientos.
    * **Firebase Storage:** Para el almacenamiento de imágenes de perfil.
* **Gestión de Estado:** `Provider` para la inyección de dependencias y `ChangeNotifier` para manejar estados globales como el del perfil de usuario.
* **Paquetes Clave de Flutter:**
    * `cloud_firestore` y `firebase_auth`
    * `provider`
    * `android_alarm_manager_plus` y `flutter_local_notifications`
    * `table_calendar`
    * `image_picker`
    * `pdf` y `printing`

## 📂 Estructura del Proyecto

El código está organizado siguiendo una arquitectura limpia para facilitar su mantenimiento y escalabilidad:

```
lib/
├── models/               # Clases de modelo (Tratamiento, Usuario) que representan los datos.
├── notifiers/            # Gestores de estado (ChangeNotifier) para la UI.
├── screens/              # Widgets que representan cada pantalla de la aplicación.
│   ├── auth/
│   ├── calendar/
│   ├── home/
│   └── ...
├── services/             # Lógica de negocio y comunicación con servicios externos (Firebase, Notificaciones).
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── notification_service.dart
│   └── tratamiento_service.dart
├── widgets/              # Widgets reutilizables (botones, campos de texto, etc.).
├── theme/                # Constantes de diseño (colores, estilos de texto).
├── enums/                # Enumeraciones personalizadas (ViewState).
├── auth_wrapper.dart     # Decide qué pantalla mostrar (Login o Home) según el estado de auth.
├── main.dart             # Punto de entrada de la aplicación y configuración de Providers.
└── alarm_callback_handler.dart # Lógica ejecutada por el gestor de alarmas en segundo plano.
```

## 🚀 Cómo Empezar

Para ejecutar este proyecto localmente, sigue estos pasos:

1.  **Clona el repositorio:**

    ```bash
    git clone [https://github.com/tu-usuario/meditime.git](https://github.com/tu-usuario/meditime.git)
    cd meditime
    ```

2.  **Instala las dependencias:**

    ```bash
    flutter pub get
    ```

3.  **Configura Firebase:**

    * Crea un nuevo proyecto en la [Consola de Firebase](https://console.firebase.google.com/).
    * Registra tus aplicaciones (Android, iOS).
    * Descarga el archivo `google-services.json` para Android y `GoogleService-Info.plist` para iOS.
    * Sigue las instrucciones de la CLI de FlutterFire para generar el archivo `firebase_options.dart`:
        ```bash
        flutterfire configure
        ```
    * Asegúrate de habilitar **Authentication** (Email/Password y Google), **Firestore Database** y **Storage** en tu proyecto de Firebase.

4.  **Ejecuta la aplicación:**

    ```bash
    flutter run
    ```

## 🤝 Contribuciones

¡Las contribuciones son bienvenidas! Si quieres mejorar MediTime, por favor sigue estos pasos:

1.  Haz un "Fork" del proyecto.
2.  Crea una nueva rama (`git checkout -b feature/nueva-funcionalidad`).
3.  Realiza tus cambios y haz "commit" (`git commit -m 'Añade nueva funcionalidad'`).
4.  Haz "Push" a la rama (`git push origin feature/nueva-funcionalidad`).
5.  Abre un "Pull Request".

## 📄 Licencia

Todos los derechos reservados 2025.

## 🙏 Agradecimientos

Un agradecimiento especial a todas las personas que contribuyeron al desarrollo y prueba de esta aplicación.

* **Programación:** Jorge Eliecer Delgado Cortés, Johan Alexander Arévalo Contréras.
* **Diseño:** Jorge Eliecer Delgado Cortés.
* **Testing:** Daniel Esteban Castiblanco, Brayan Esteban Salinas, Santiago Garzón Cuadrado, y más.
* A la **Universidad de Cundinamarca**, seccional Ubaté, por incentivar el desarrollo de proyectos innovadores.