# GUÍA OFICIAL DE SUSTENTACIÓN PGC — MEDITIME (v2.37.0)
## PROYECTO: MEDITIME: APLICACIÓN MÓVIL PARA LA GESTIÓN INTEGRAL DE RECETAS MÉDICAS Y CONTROL DE PRESCRIPCIONES
### AUTORES: JOHAN ALEXANDER ARÉVALO CONTRERAS & JORGE ELIECER DELGADO CORTÉS
### PROGRAMA DE INGENIERÍA DE SISTEMAS • UNIVERSIDAD DE CUNDINAMARCA — SECCIONAL UBATÉ

---

### ⏱️ CRONOMETRAJE CALIBRADO (15 MINUTOS TOTALES — 13 DIAPOSITIVAS)

```
[00:00 - 00:45]  Slide 1:  Portada Institucional (Título oficial, autores y programa de Ingeniería de Sistemas) (45 s)
[00:45 - 01:40]  Slide 2:  Definición del Problema (~50% no adherencia OMS, Cundinamarca y pregunta problema) (55 s)
[01:40 - 02:30]  Slide 3:  Justificación (Valor técnico en Vision AI/alarmas nativas y valor social inclusivo) (50 s)
[02:30 - 03:15]  Slide 4:  Objetivos del Proyecto (Objetivo General y 5 Específicos exactos de tu documento) (45 s)
[03:15 - 04:15]  Slide 5:  Marco de Referencia y Legal (70% efectividad mHealth Domenech, leyes 1581, 23, 527, 1438) (60 s)
[04:15 - 05:15]  Slide 6:  Metodología Kanban y Cronograma Real (Tablero Trello y 64.3% de actividades cerradas) (60 s)
[05:15 - 06:15]  Slide 7:  Clean Architecture y Stack Tecnológico (Capas Core, Domain, Data, Flutter, Groq, SQLite) (60 s)
[06:15 - 07:15]  Slide 8:  Ecosistema MediTime (App Móvil v2.37 + Plataforma Web conectada a GitHub Releases) (60 s)
-----------------------------------------------------------------------------------------------------------------
[07:15 - 12:00]  Slide 9:  DEMOSTRACIÓN EN VIVO (LIVE DEMO - ¡Casi 5 MINUTOS PARA LUCIRSE!)
                           • Paso 1: Navegación en el Sitio Web oficial y descarga directa del APK en GitHub.
                           • Paso 2: Escaneo/registro de receta con cálculo automatizado de tomas.
                           • Paso 3: Disparo de Alarma Nativa a pantalla completa (rompe Doze Mode).
                           • Paso 4: Consulta interactiva con el Asistente Midi AI por voz/chat (Groq LPU).
                           • Paso 5: Vista de supervisión en Modo Cuidador y reporte clínico en PDF (fl_chart).
-----------------------------------------------------------------------------------------------------------------
[12:00 - 13:00]  Slide 10: Alcances y Desafíos de Despliegue (Tránsito a Play Store, pruebas, monitoreo nube) (60 s)
[13:00 - 14:00]  Slide 11: Minuto en Inglés (Official Abstract del documento de grado) (60 s)
[14:00 - 14:40]  Slide 12: Conclusiones de Ingeniería (Diapositiva propia de balance técnico - Doc Pág. 19-20) (40 s)
[14:40 - 15:00]  Slide 13: Cierre Institucional ("¡Transformemos la salud en Colombia!"), QR y Preguntas (20 s)
=================================================================================================================
TOTAL: 15 minutos exactos de exposición + 5 minutos de intervención del jurado evaluador.
```

---

### 🎙️ GUION OFICIAL PARA EL MINUTO EN INGLÉS (SLIDE 11 — 60 SEGUNDOS)

Al pasar a la diapositiva 11, di con tranquilidad:
*"A continuación, presentaré el resumen de investigación y alcance de nuestro proyecto en el minuto en inglés reglamentario:"*

> *"Distinguished members of the evaluation committee:*
> 
> *This project consolidates MediTime (v2.37.0), a comprehensive mobile solution designed to maximize compliance and accuracy in medical prescription management by leveraging emerging technologies.*
> 
> *Built on Flutter and supported by Google Firebase and Groq LPU, the application surpasses conventional apps by integrating vision-based OCR extraction of handwritten prescriptions and conversational assistance via Midi AI.*
> 
> *Furthermore, high-priority full-screen native alarms reliably bypass Android Doze Mode, while Caregiver and Pets modes expand social supervision for dependent family members.*
> 
> *Finally, supported by our open-source web platform connected to GitHub Releases, MediTime ensures direct access, patient autonomy, and medication safety.*
> 
> *Thank you very much."*

---

### 💡 LIBRETO PARA LAS CONCLUSIONES DE INGENIERÍA (SLIDE 12 — 40 SEGUNDOS)

Al llegar a la diapositiva 12, expones los 4 balances técnicos demostrados:

1. **Visión AI y PLN:** *"Demostramos que la visión por computadora y los modelos de lenguaje reducen drásticamente la fricción y el error humano en el registro de medicamentos."*
2. **Alarmas Nativas:** *"Las alarmas a pantalla completa integradas al sistema operativo solucionaron definitivamente la omisión de dosis provocada por los modos de ahorro de batería de Android."*
3. **Cuidado Colaborativo:** *"Con el Modo Cuidador y Modo Animales, MediTime evolucionó de una app personal a un centro de supervisión clínica colaborativa para el hogar."*
4. **Disponibilidad Offline:** *"La arquitectura híbrida con SQLite local y reportes en PDF garantiza operatividad continua en zonas rurales sin conexión a internet."*

---

### 📱 GUION ESTRATÉGICO PARA LA DEMO EN VIVO (SLIDE 9 — 4.5 A 5 MINUTOS)

1. **Plataforma Web y GitHub Releases (1 minuto):**
   - Muestra el navegador: *"Comenzamos con nuestro canal de despliegue y difusión. Para evitar las barreras de las tiendas cerradas, creamos el sitio web oficial de MediTime. Desde allí cualquier usuario o médico puede consultar la arquitectura del sistema, los manuales y descargar directamente el paquete APK Release firmado desde nuestro repositorio oficial de GitHub."*
2. **Registro de Receta y Alarmas (1.5 minutos):**
   - En tu teléfono móvil: *"En la aplicación MediTime, el paciente registra su prescripción médica. El sistema calcula de inmediato los intervalos y almacena los datos de forma local en SQLite para operar offline. Demostramos cómo la alarma nativa (AlarmRingingPage) se ejecuta en pantalla completa con prioridad máxima, garantizando que el paciente reciba el recordatorio incluso si el teléfono entra en suspensión profunda."*
3. **Asistente Conversacional Midi AI (1 minuto):**
   - Interactúa con el chatbot: *"Incorporamos el asistente Midi AI conectado a Groq LPU y reconocimiento de voz Whisper. El usuario puede preguntar por lenguaje natural sobre dudas de administración y horarios, obteniendo respuesta contextual en menos de dos segundos."*
4. **Modo Cuidador y Reporte en PDF (1 minuto):**
   - Muestra el cambio de perfil: *"Pensando en pacientes dependientes, el Modo Cuidador unifica la supervisión del tratamiento y permite generar informes clínicos estandarizados en PDF con gráficas de cumplimiento (fl_chart) para que el paciente los comparta con su médico tratante."*

---

### 🛡️ PREGUNTAS CLAVE DEL JURADO Y RESPUESTAS BASADAS EN TU DOCUMENTO

#### P1: ¿Por qué la aplicación aún no está publicada en Google Play Store?
* **Respuesta Técnica:** *(Basada en la pág. 18 de tu documento)* *"El proceso de publicación en Google Play Store exige actualmente un periodo cerrado obligatorio de 14 días con 20 evaluadores antes del lanzamiento masivo. En nuestro cronograma de trabajo de grado, priorizamos primero el aseguramiento del núcleo de software (alarmas nativas, persistencia offline y seguridad de datos bajo Ley 1581) y garantizamos el acceso inmediato mediante nuestro sitio web oficial conectado a GitHub Releases."*

#### P2: ¿Cómo garantizan que la aplicación funcione si el paciente no tiene internet?
* **Respuesta Técnica:** *(Basada en la pág. 9 y 18)* *"MediTime implementa una arquitectura híbrida offline-first. Aunque la sincronización en la nube utiliza Firebase y la IA usa Groq, la base de datos local almacena en caché persistente todos los tratamientos y horarios. Por tanto, el paciente puede consultar sus recetas, recibir sus alarmas de hardware y registrar sus tomas en cualquier zona rural o sin cobertura."*

#### P3: ¿La aplicación puede sustituir la prescripción de un médico?
* **Respuesta Técnica:** *(Basada en la pág. 9 y 14)* *"En absoluto. En estricto cumplimiento del Código de Ética Médica (Ley 23 de 1981), la prescripción es un acto exclusivo de profesionales de la salud autorizados. MediTime opera como una herramienta tecnológica de soporte y seguimiento informativo, evitando que el paciente olvide sus dosis o cometa errores en los horarios recetados."*
