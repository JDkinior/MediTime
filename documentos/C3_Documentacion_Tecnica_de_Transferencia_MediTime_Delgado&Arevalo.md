# UNIVERSIDAD DE CUNDINAMARCA
## FACULTAD DE INGENIERÍA
### PROGRAMA ACADÉMICO DE INGENIERÍA DE SISTEMAS Y COMPUTACIÓN
### CAMPO DE APRENDIZAJE INSTITUCIONAL: CIENCIA, TECNOLOGÍA E INNOVACIÓN (CTeI)
#### PROYECTO DE GRADO - NOVENO SEMESTRE (PGC) - VIGENCIA 2026

---

# C3 DOCUMENTACIÓN TÉCNICA DE TRANSFERENCIA Y DEVOLUCIÓN AL TERRITORIO
## COMPILACIÓN OFICIAL: MANUAL DE USUARIO, MANUAL TÉCNICO Y PLAN DE SOSTENIBILIDAD
### DESARROLLO DE UNA APLICACIÓN MÓVIL PARA LA GESTIÓN DE TRATAMIENTOS MÉDICOS (MEDITIME)

---

### FICHA TÉCNICA DE PORTADA INSTITUCIONAL

| Campo Institucional | Detalle Oficial del Proyecto |
| :--- | :--- |
| **Título del Proyecto:** | Desarrollo de una Aplicación Móvil para la Gestión de Tratamientos Médicos (MediTime) |
| **Versión del Software:** | 2.31.1 (Corte 3 - Versión Final Desplegada y Mantenible) |
| **Autores / Investigadores:** | **Jorge Eliecer Delgado Cortés**<br>**Johan Alexander Arévalo Contreras** |
| **Programa Académico:** | Ingeniería de Sistemas y Computación |
| **Facultad:** | Facultad de Ingeniería |
| **Institución Universitaria:** | Universidad de Cundinamarca - Seccional Ubaté |
| **Campo de Aprendizaje:** | Ciencia, Tecnología e Innovación (CTeI) / PGC 9° Semestre |
| **Gestora del Conocimiento:** | Ing. Nohora Angélica Millán Aldana |
| **Eje Estratégico:** | Modelo Educativo Digital Transmoderno (MEDIT) - Transferencia y Devolución al Territorio |
| **Lugar y Fecha:** | Ubaté, Cundinamarca, Colombia – 2026 |

---

## TABLA GENERAL DE CONTENIDO

- **VOLUMEN I: MANUAL DE USUARIO (GUÍA OPERATIVA Y DE ACCESIBILIDAD)**
  1. Introducción y Propósito del Manual
  2. Requisitos del Sistema y Dispositivos Compatibles
  3. Configuración Inicial y Permisos del Sistema Operativo
  4. Autenticación y Perfil de Usuario
  5. Gestión Integral de Tratamientos y Medicamentos
  6. Sistema de Recordatorios, Notificaciones y Alarmas
  7. Calendario Interactivo y Registro Cronológico
  8. Modo Cuidador (Familiar y Asistencial / Clínico)
  9. Modo Animales y Veterinaria (Gestión de Mascotas y Clínicas Veterinarias)
  10. Asistente Virtual Inteligente Midi (IA Generativa)
  11. Módulo de Adherencia Terapéutica y Reportes Clínicos en PDF
  12. Herramientas Complementarias y Accesibilidad
  13. Guía de Optimización de Batería por Fabricante
  14. Preguntas Frecuentes (FAQ) y Soporte Técnico

- **VOLUMEN II: MANUAL TÉCNICO DE ARQUITECTURA E INGENIERÍA**
  1. Introducción y Resumen Técnico
  2. Ficha Técnica del Sistema y Stack Tecnológico
  3. Arquitectura de Software y Patrones de Diseño (Clean Architecture, Result, Lazy Loading)
  4. Desglose Exhaustivo del Código Fuente (Estructura `lib/` al 100%)
  5. Modelo de Datos y Persistencia NoSQL (Cloud Firestore)
  6. Arquitectura de Segundo Plano y Motor de Alarmas de Hardware
  7. Integración de Inteligencia Artificial Generativa (Groq API, Streaming y Tool Calling)
  8. Georreferenciación y Tecnologías Asistivas
  9. Guía de Instalación, Compilación y Despliegue en Producción
  10. Aseguramiento de Calidad, Linter y Pruebas del Sistema

- **VOLUMEN III: PLAN DE SOSTENIBILIDAD, GOBERNANZA Y DEVOLUCIÓN AL TERRITORIO**
  1. Introducción y Justificación del Plan
  2. Articulación con el Modelo Educativo MEDIT y la Devolución al Territorio
  3. Gobernanza, Estructura Organizacional y Asignación de Roles (Matriz RACI)
  4. Presupuesto y Recursos Asignados (Cloud, Licenciamiento y Recursos Humanos)
  5. Plan de Mantenimiento y Ciclo de Vida del Software (Correctivo, Preventivo, Adaptativo)
  6. Estrategia de Transferencia y Apropiación Social del Conocimiento
  7. Matriz de Gestión de Riesgos y Plan de Continuidad Operativa
  8. Conclusiones y Compromiso Institucional de Continuidad

- **REFERENCIAS BIBLIOGRÁFICAS (NORMA APA 7ª EDICIÓN)**

---

# ==========================================
# VOLUMEN I: MANUAL DE USUARIO
# ==========================================

## 1. INTRODUCCIÓN Y PROPÓSITO DEL MANUAL
El presente manual tiene por finalidad guiar a los pacientes, familiares y cuidadores en el uso óptimo de **MediTime v2.31.1**, permitiendo la administración rigurosa y sencilla de tratamientos médicos, el seguimiento visual del cumplimiento y la prevención del olvido en la toma de medicamentos.

## 2. REQUISITOS DEL SISTEMA Y DISPOSITIVOS COMPATIBLES
- **Sistema Operativo:** Android 8.0 (Oreo / API Level 26) o superior.
- **Hardware Recomendado:** Memoria RAM de 2.0 GB o superior, almacenamiento libre mínimo de 100 MB.
- **Conectividad:** Acceso a internet para sincronización con Firebase y consultas al asistente Midi. (*Las alarmas programadas operan de forma 100% autónoma sin internet*).
- **Periféricos:** Cámara integrada para digitalización de recetas y sensor GPS para el mapa de farmacias.

## 3. CONFIGURACIÓN INICIAL Y PERMISOS DEL SISTEMA OPERATIVO
Al iniciar la aplicación, se deben autorizar los siguientes permisos esenciales:
- **Alarmas exactas (`SCHEDULE_EXACT_ALARM`):** Garantiza la precisión temporal de cada recordatorio.
- **Exclusión de optimización de batería:** Seleccionar "Sin restricciones" para evitar que el fabricante cierre las alarmas en segundo plano.
- **Notificaciones y Pantalla Completa:** Autoriza el encendido de pantalla ante emergencias de toma de dosis.
- **Cámara y Almacenamiento:** Para capturar fórmulas médicas y actualizar la fotografía de perfil.

## 4. AUTENTICACIÓN Y PERFIL DE USUARIO
- **Registro de Cuentas:** Permite crear credenciales mediante nombre, correo electrónico y contraseña segura.
- **Inicio de Sesión:** Admite acceso estándar o mediante **Google Sign-In** en un solo toque.
- **Recuperación de Contraseña:** Envío automático de enlace de restablecimiento al correo institucional o personal.
- **Perfil Médico:** Registro de tipo de sangre, alergias farmacológicas, antecedentes clínicos y contacto de emergencia.
- **Tutorial Guiado (Showcase):** Recorrido interactivo con globos explicativos al abrir la aplicación por primera vez.

## 5. GESTIÓN INTEGRAL DE TRATAMIENTOS Y MEDICAMENTOS
- **Alta de Receta:** Botón flotante circular `+` en la pantalla principal.
- **Parámetros del Fármaco:** Nombre del medicamento, presentación (tabletas, jarabe, gotas, cápsulas, inyectable, inhalador), dosis por toma e intervalo de recurrencia en horas.
- **Tratamientos Indefinidos / Continuos:** Modalidad para patologías crónicas soportada por el motor *Lazy Loading* para no saturar memoria.
- **Control de Stock e Inventario:** Indicación de unidades en caja y unidades restantes; alerta automática al descender del 20% o menos de 5 unidades.
- **Edición y Cancelación:** Modificación ágil de posologías y cancelación de tratamientos con purga inmediata de alarmas en el hardware.

## 6. SISTEMA DE RECORDATORIOS, NOTIFICACIONES Y ALARMAS
- **Modos de Operación:**
  * *Modo Alarma (Recomendado):* Activa la pantalla completa (`AlarmRingingPage`), reproduce tono continuo y vibración persistente.
  * *Modo Activo:* Notificación flotante con botones interactivos.
  * *Modo Pasivo / Automático:* Notificación informativa con registro automático de toma.
- **Acciones sobre la Toma:**
  * **TOMAR (Verde):** Detiene el sonido, deduce del inventario y marca la dosis como tomada.
  * **POSPONER / SNOOZE (Amarillo):** Silencia momentáneamente y reactiva la alarma tras el lapso de aplazamiento configurado (10, 15 o 30 min).
  * **OMITIR (Rojo):** Registra voluntariamente la dosis como no consumida para auditoría médica.

## 7. CALENDARIO INTERACTIVO Y REGISTRO CRONOLÓGICO
- **Vista Mensual:** Días con dosis señalados mediante indicadores visuales circulares.
- **Semaforización de Estados (`DoseStatus`):**
  * *Gris:* Dosis Pendiente.
  * *Ámbar / Amarillo:* Dosis Notificada.
  * *Verde:* Dosis Tomada.
  * *Rojo:* Dosis Omitida.
  * *Naranja:* Dosis Aplazada.
- **Auditoría Retrospectiva:** Confirmación manual de dosis pasadas no marcadas a tiempo.

## 8. MODO CUIDADOR (FAMILIAR Y ASISTENCIAL / CLÍNICO)
- **Supervisión Multi-Paciente:** Creación de múltiples perfiles bajo el cuidado del usuario principal con asignación de color temático individual.
- **Tema Morado Suave:** Paleta en Morado Lavanda Suave (`#8B62D4`) y fondos crema pastel (`#FAF8F5`) para inmediata diferenciación asistencial.
- **Menú Lateral Adaptativo:** Iconos y contenedores del Drawer sincronizados dinámicamente con la paleta morada (manteniendo únicamente Salir en rojo).
- **Exclusividad Mutua:** Conmutación automática con Modo Animales; encender Modo Cuidador desactiva Modo Animales para prevenir mezclas de pacientes.
- **Modalidad Familiar y Asistencial:** Nombres afectivos, asignación de cama/habitación, categoría por piso y notas para enfermería.
- **Vinculación Remota:** Sincronización en tiempo real mediante correo electrónico (`linkedUid`).

## 9. MODO ANIMALES Y VETERINARIA (GESTIÓN DE MASCOTAS Y CLÍNICAS VETERINARIAS)
- **Tema Verde Salvia / Crema Menta:** Paleta suave y relajante (`#389E6A` / `#52B788`) con fondos claros y oscuros de confort visual (`#F9FAF5` / `#101713`).
- **Menú Lateral Adaptativo:** Iconos y contenedores del Drawer sincronizados dinámicamente con la paleta verde salvia (manteniendo únicamente Salir en rojo).
- **Autonomía Operativa Completa:** Funciona de manera 100% independiente sin requerir Modo Cuidador. Incluye selector superior de mascotas (`Icons.pets_rounded`), vista general de tratamientos animales y sincronización con calendario.
- **Exclusividad Mutua:** Al activarse desactiva Modo Cuidador garantizando aislamiento estricto entre historiales de mascotas y pacientes humanos.
- **Mascota Individual vs. Clínica Veterinaria:** Configuración para dueños de un único animal de compañía o para clínicas veterinarias, albergues y centros de rescate con múltiples pacientes hospitalizados.
- **Ficha Zootécnica Completa:** Registro exhaustivo de especie (canino, felino, equino, bovino, ave, conejo, etc.), raza, peso en kilogramos, código oficial de microchip o tatuaje, y ubicación de jaula o box.
- **Posología y Notificaciones Veterinarias:** Asociación directa de fármacos a la mascota, recordatorios personalizados y control riguroso de inventario de medicamentos veterinarios.

## 10. ASISTENTE VIRTUAL INTELIGENTE MIDI (IA GENERATIVA)
- **Interacción Bilingüe:** Detección automática y respuesta fluida en español o inglés con avatar animado.
- **Ejecución de Herramientas (Tool Calling):** Consultas de medicamentos de hoy (`get_today_medications`), tomas de mañana y creación conversacional de recetas (`create_treatment`).
- **Visión Artificial Multimodal:** Escaneo fotográfico de recetas médicas manuscritas y cajas de medicamentos para autorelleno de tratamientos.

## 11. MÓDULO DE ADHERENCIA Y REPORTES CLÍNICOS EN PDF
- **Métricas de Cumplimiento:** Cálculo porcentual formal de adherencia y gráficas temporales con `fl_chart`.
- **Exportación en PDF:** Generación en el dispositivo de reportes oficiales en formato A4 con encabezado, gráficas, tabla detallada por medicamento o animal y sección para firma del profesional tratante.

## 12. HERRAMIENTAS COMPLEMENTARIAS Y ACCESIBILIDAD
- **Modo Simplificado:** Fuentes ampliadas y alto contraste para personas mayores.
- **Soporte de Voz:** Lectura auditiva de prescripciones con `flutter_tts` y dictado de notas con `record`.
- **Localizador de Farmacias:** Mapa dinámico con `maplibre_gl` y cálculo de proximidad vía GPS.
- **Widget de Escritorio Android:** Visualización permanente de la siguiente dosis en la pantalla de inicio del teléfono (`home_widget`).

## 13. GUÍA DE OPTIMIZACIÓN DE BATERÍA POR FABRICANTE
Procedimientos detallados para deshabilitar la suspensión de procesos en segundo plano y autorizar el inicio automático en dispositivos Xiaomi/MIUI, Samsung/One UI, Huawei/EMUI y Motorola.

## 14. PREGUNTAS FRECUENTES (FAQ) Y SOPORTE TÉCNICO
Resolución de dudas sobre el funcionamiento offline, resincronización de datos en la nube y canales de atención de los ingenieros desarrolladores de la Universidad de Cundinamarca.

---

# ==========================================
# VOLUMEN II: MANUAL TÉCNICO DE ARQUITECTURA
# ==========================================

## 1. INTRODUCCIÓN Y RESUMEN TÉCNICO
MediTime (v2.31.1) es una aplicación móvil construida en Flutter/Dart, respaldada por servicios serverless de Google Cloud Firebase y modelos cognitivos alojados en Groq Cloud API.

## 2. FICHA TÉCNICA DEL SISTEMA
- **Framework:** Flutter SDK 3.7.0+ / Dart 3.7+ con Sound Null Safety.
- **Plataforma:** Android SDK min 26, target 34 (compatible con Android 14 y 15).
- **Persistencia NoSQL:** Google Cloud Firestore con soporte offline.
- **Servicios Cloud:** Firebase Authentication, Cloud Storage / Cloudinary.
- **IA y Visión:** Groq Cloud API (`llama-3.3-70b-versatile`, `llama-3.1-8b-instant`, `qwen/qwen3.6-27b`).
- **Nativo Android:** `android_alarm_manager_plus`, `flutter_local_notifications`, `flutter_ringtone_player`.

## 3. ARQUITECTURA DE SOFTWARE Y PATRONES DE DISEÑO
- **Clean Architecture:** Desacoplamiento riguroso en capas de Presentación (`screens/`, `notifiers/`), Dominio (`models/`, `use_cases/`) y Datos (`repositories/`, `services/`).
- **Repository Pattern:** Abstracción del acceso a datos mediante `TreatmentRepository` y `UserRepository`.
- **Result Pattern:** Gestión funcional y tipada de errores mediante la clase sellada `Result<T>` (`Success<T>` y `Failure<T>`).
- **Gestión de Estado Reactiva:** Inyección de dependencias centralizada con `MultiProvider` y `ChangeNotifier`.
- **Lazy Loading y StreamCache:** Generación procedural de dosis futuras en tratamientos indefinidos con memoria O(1) y reuso de suscripciones a Firestore.

## 4. DESGLOSE EXHAUSTIVO DEL CÓDIGO FUENTE (ESTRUCTURA LIB/)
- **`lib/core/`:** Constantes globales (`constants.dart`), patrón `result.dart`, georreferenciación (`location_helper.dart`), `stream_cache.dart`, `treatment_constants.dart`, `utils.dart` y `navigator_key.dart` para navegación desacoplada.
- **`lib/models/`:** Entidades inmutables `Tratamiento`, `Usuario`, `CaregiverProfile`, `LazyTreatment`, `TreatmentFormData` y enums `DoseStatus` y `ViewState`.
- **`lib/repositories/`:** Contratos abstractos e implementaciones concretas en Cloud Firestore.
- **`lib/use_cases/`:** Casos de uso atómicos `LoadUserProfileUseCase` y `SignOutUseCase`.
- **`lib/services/`:** Servicios de alta cohesión:
  * `notification_service.dart`: Canales de alta importancia, full-screen intent y callbacks de acción.
  * `alarm_callback_handler.dart`: Isolate nativo en segundo plano (`@pragma('vm:entry-point')`), guard de usuario revocado y audio continuo.
  * `gemini_service.dart`: Conexión SSE con Groq Cloud API, Tool Calling y visión artificial.
  * `firestore_service.dart`: Transacciones atómicas y batch writes.
  * `preference_service.dart`: Persistencia en SharedPreferences.
  * `pdf_report_service.dart`: Composición procedural de reportes clínicos en PDF.
  * `voice_service.dart`, `system_settings_service.dart`, `storage_service.dart`, `widget_service.dart`.
- **`lib/notifiers/`:** Gestores reactivos de estado para perfil, preferencias, cuidador, formulario y calendario.
- **`lib/screens/` y `lib/widgets/`:** Vistas modulares para alarmas, autenticación, calendario, cuidador, chatbot, home, medicación, reportes y accesibilidad.
- **`main.dart` y `auth_wrapper.dart`:** Puntos de entrada e inicialización de la arquitectura.

## 5. MODELO DE DATOS Y PERSISTENCIA (CLOUD FIRESTORE)
- **Colecciones:** `users`, subcolecciones `userMedicamentos`, `caregiverProfiles` y compatibilidad con `medicamentos`.
- **Reglas de Seguridad (`firestore.rules`):** Aislamiento estricto de lectura y escritura condicionado al identificador único del usuario autenticado (`request.auth.uid == userId`).

## 6. ARQUITECTURA DE SEGUNDO PLANO Y ALARMAS DE HARDWARE
- **Isolate de Dart:** La función `alarmCallbackLogic` se ejecuta en un hilo de hardware sin interfaz gráfica.
- **Permisos Nativo-Android:** `SCHEDULE_EXACT_ALARM`, `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED`, `SYSTEM_ALERT_WINDOW`.
- **Resiliencia Offline-First:** Las alarmas se procesan con la información contenida en el payload local sin depender de disponibilidad de red.

## 7. INTEGRACIÓN DE INTELIGENCIA ARTIFICIAL (GROQ API)
- **Protocolo:** Streaming Server-Sent Events (SSE) con baja latencia (~500ms al primer token).
- **Tool Calling:** Detección de intenciones y ejecución de métodos en cliente para consulta y alta de tratamientos sin alucinaciones de datos.

## 8. GEORREFERENCIACIÓN Y TECNOLOGÍAS ASISTIVAS
- Consumo de nodos Overpass API de OpenStreetMap mediante cálculo geodésico haversiano en `LocationHelper`.
- Síntesis de voz en español mediante `flutter_tts` y captura mediante `record`.

## 9. GUÍA DE COMPILACIÓN Y DESPLIEGUE
- Inyección de variables en release: `flutter build apk --release --dart-define=GROQ_API_KEY=...`.
- Configuración de certificados de firma digital (Keystore RSA 2048 bits con vigencia de 25 años).

## 10. ASEGURAMIENTO DE CALIDAD Y PRUEBAS
- Reglas de análisis estático con `flutter_lints` en `analysis_options.yaml`.
- Batería de pruebas unitarias y de integración sobre servicios y modelos.

---

# ==========================================
# VOLUMEN III: PLAN DE SOSTENIBILIDAD
# ==========================================

## 1. INTRODUCCIÓN Y JUSTIFICACIÓN
El Plan de Sostenibilidad establece el modelo operativo, organizativo y financiero que garantiza la continuidad y el impacto positivo de MediTime en la comunidad.

## 2. ARTICULACIÓN CON EL MEDIT Y DEVOLUCIÓN AL TERRITORIO
- **Modelo Educativo Digital Transmoderno (MEDIT):** Fomenta la formación de seres libres, autónomos y responsables mediante el diálogo y la apropiación tecnológica.
- **Impacto Territorial:** Mitigación de la tasa de no adherencia farmacológica en la Provincia de Ubaté y Cundinamarca, especialmente en adultos mayores con polifarmacia y enfermedades crónicas.
- **Alineación con los ODS:** Contribución al ODS 3 (Salud y Bienestar), ODS 9 (Innovación e Infraestructura) y ODS 10 (Reducción de las Desigualdades).

## 3. GOBERNANZA Y ASIGNACIÓN DE ROLES (MATRIZ RACI)
- **Equipo Desarrollador e Investigador:** Jorge Eliecer Delgado Cortés (Arquitectura y DevOps) y Johan Alexander Arévalo Contreras (Calidad y Transferencia).
- **Asesoría Académica Institucional:** Ing. Nohora Angélica Millán Aldana (Universidad de Cundinamarca).
- **Actores Receptores:** Centros de salud, droguerías, hogares de paso, cuidadores y pacientes de Ubaté.
- **Matriz RACI:** Distribución de responsabilidades para soporte de servidores, hotfixes, actualizaciones de Android SDK y talleres formativos.

## 4. PRESUPUESTO Y RECURSOS ASIGNADOS
- **Costo Inicial de Nube:** $0 COP mensuales mediante los niveles gratuitos empresariales de Firebase Spark, Groq Cloud API y Cloudinary, con capacidad para más de 3.000 usuarios activos.
- **Licenciamiento y Distribución:** Cuenta de desarrollador Google Play Console ($25 USD pago único) financiada por el equipo.
- **Recursos Humanos:** Horas de ingeniería aportadas por los desarrolladores para soporte y transferencia territorial.

## 5. PLAN DE MANTENIMIENTO Y CICLO DE VIDA DEL SOFTWARE
- **Mantenimiento Correctivo:** SLAs con tiempo de respuesta menor a 12 horas para fallas críticas en alarmas y despliegue de hotfixes en menos de 48 horas.
- **Mantenimiento Preventivo y Adaptativo:** Auditorías trimestrales de código y verificación anual ante nuevas versiones de Android (15 y 16).
- **Roadmap a 24 Meses:** Integración con Google Health Connect, alertas SMS de emergencia y portal clínico para profesionales de salud.

## 6. ESTRATEGIA DE TRANSFERENCIA Y APROPIACIÓN SOCIAL
- **Protocolo de Entrega Formal:** Radicación de acta de transferencia y depósito del repositorio Git con etiqueta `v2.31.1-final` bajo licencia académica y social para la Universidad de Cundinamarca.
- **Capacitación Comunitaria:** Ciclo de 3 talleres sobre salud digital, rol del cuidador y uso de reportes de adherencia.
- **Material Didáctico:** Cartillas ilustradas e infografías de lectura fácil para la comunidad de Ubaté.

## 7. MATRIZ DE GESTIÓN DE RIESGOS Y CONTINUIDAD OPERATIVA
Planes de contingencia ante modificaciones de cuotas de APIs de IA, optimización de batería agresiva por fabricantes y protección de datos médicos bajo la Ley 1581 de 2012.

## 8. CONCLUSIONES
MediTime consolida una propuesta de ingeniería de software madura, sostenible y pertinente para el territorio, dejando capacidad instalada y herramientas de salud pública en beneficio de Cundinamarca.

---

## REFERENCIAS BIBLIOGRÁFICAS (NORMA APA 7ª EDICIÓN)

- Congreso de la República de Colombia. (2012). *Ley Estatutaria 1581 de 2012, por la cual se dictan disposiciones generales para la protección de datos personales*. Diario Oficial No. 48.587.
- Flutter Development Team. (2024). *Flutter documentation: Architectural overview and state management*. Google LLC. https://docs.flutter.dev/
- Google Cloud. (2024). *Firebase documentation: Cloud Firestore and Authentication security rules*. Google Cloud Platform. https://firebase.google.com/docs
- Groq Cloud. (2024). *Groq LPU Inference Engine API documentation and function calling reference*. Groq Inc. https://console.groq.com/docs
- Martin, R. C. (2018). *Clean Architecture: A craftsman's guide to software structure and design*. Prentice Hall.
- Organización Mundial de la Salud [OMS]. (2023). *Adherencia a los tratamientos a largo plazo: pruebas para la acción*. Organización Mundial de la Salud.
- Organización de las Naciones Unidas [ONU]. (2015). *Transformar nuestro mundo: la Agenda 2030 para el Desarrollo Sostenible*. Resolución aprobada por la Asamblea General de la ONU.
- Universidad de Cundinamarca. (2020). *Modelo Educativo Digital Transmoderno (MEDIT)*. Editorial Universidad de Cundinamarca.
