# UNIVERSIDAD DE CUNDINAMARCA
## FACULTAD DE INGENIERÍA
### PROGRAMA ACADÉMICO DE INGENIERÍA DE SISTEMAS Y COMPUTACIÓN
### CAMPO DE APRENDIZAJE INSTITUCIONAL: CIENCIA, TECNOLOGÍA E INNOVACIÓN (CTeI)
#### PROYECTO DE GRADO - NOVENO SEMESTRE (PGC) - VIGENCIA 2026

---

# C3 MANUAL DE USUARIO
## DESARROLLO DE UNA APLICACIÓN MÓVIL PARA LA GESTIÓN DE TRATAMIENTOS MÉDICOS (MEDITIME)

---

### FICHA TÉCNICA DE PORTADA INSTITUCIONAL

| Campo Institucional | Detalle Oficial del Proyecto |
| :--- | :--- |
| **Título del Proyecto:** | Desarrollo de una Aplicación Móvil para la Gestión de Tratamientos Médicos (MediTime) |
| **Versión del Software:** | 2.31.1 |
| **Autores / Investigadores:** | **Jorge Eliecer Delgado Cortés**<br>**Johan Alexander Arévalo Contreras** |
| **Programa Académico:** | Ingeniería de Sistemas y Computación |
| **Facultad:** | Facultad de Ingeniería |
| **Institución Universitaria:** | Universidad de Cundinamarca - Seccional Ubaté |
| **Campo de Aprendizaje:** | Ciencia, Tecnología e Innovación (CTeI) / PGC 9° Semestre |
| **Gestora del Conocimiento:** | Ing. Nohora Angélica Millán Aldana |
| **Comunidad y Territorio:** | Población de pacientes crónicos y red de cuidadores de la Provincia de Ubaté y Cundinamarca |
| **Lugar y Fecha:** | Ubaté, Cundinamarca, Colombia – 2026 |

---

## TABLA DE CONTENIDO

1. [INTRODUCCIÓN Y PROPÓSITO DEL MANUAL](#1-introducción-y-propósito-del-manual)
2. [REQUISITOS DEL SISTEMA Y DISPOSITIVOS COMPATIBLES](#2-requisitos-del-sistema-y-dispositivos-compatibles)
3. [CONFIGURACIÓN INICIAL Y PERMISOS DEL SISTEMA OPERATIVO](#3-configuración-inicial-y-permisos-del-sistema-operativo)
4. [AUTENTICACIÓN Y PERFIL DE USUARIO](#4-autenticación-y-perfil-de-usuario)
   - 4.1. Registro de Nuevas Cuentas
   - 4.2. Inicio de Sesión Estándar y Acceso Federado con Google
   - 4.3. Recuperación de Credenciales de Acceso
   - 4.4. Diligenciamiento y Actualización del Perfil Médico
   - 4.5. Tutorial Interactivo Guiado (Showcase)
5. [GESTIÓN INTEGRAL DE TRATAMIENTOS Y MEDICAMENTOS](#5-gestión-integral-de-tratamientos-y-medicamentos)
   - 5.1. Registro y Alta de un Tratamiento Farmacológico
   - 5.2. Selección de Presentación, Dosis e Intervalos Horarios
   - 5.3. Tratamientos Continuos o Indefinidos (Patologías Crónicas)
   - 5.4. Control de Inventario y Alerta Preventiva de Stock Bajo
   - 5.5. Consulta, Edición, Suspensión y Eliminación de Recetas
6. [SISTEMA DE RECORDATORIOS, NOTIFICACIONES Y ALARMAS](#6-sistema-de-recordatorios-notificaciones-y-alarmas)
   - 6.1. Modalidades de Notificación: Pasiva, Activa y Modo Alarma
   - 6.2. Pantalla de Alarma Persistente y Acciones Rápidas (Tomar, Posponer, Omitir)
   - 6.3. Configuración de Tiempos de Aplazamiento (Snooze) y Tonos
7. [CALENDARIO INTERACTIVO Y REGISTRO CRONOLÓGICO](#7-calendario-interactivo-y-registro-cronológico)
   - 7.1. Vista Mensual y Diaria de Tomas Programadas
   - 7.2. Código Cromático de Estados de Dosis
   - 7.3. Auditoría y Registro Retrospectivo de Medicación
8. [MODO CUIDADOR (FAMILIAR Y ASISTENCIAL / CLÍNICO)](#8-modo-cuidador-familiar-y-asistencial--clínico)
   - 8.1. Gestión Multi-Paciente y Creación de Perfiles Dependientes
   - 8.2. Modalidad Familiar vs. Modalidad Clínica
   - 8.3. Vinculación Remota de Cuentas de Pacientes
9. [MODO ANIMALES Y VETERINARIA (GESTIÓN DE MASCOTAS Y CLÍNICAS VETERINARIAS)](#9-modo-animales-y-veterinaria-gestión-de-mascotas-y-clínicas-veterinarias)
   - 9.1. Activación y Adaptación Visual Dinámica (Tema Verde Veterinario)
   - 9.2. Modalidades: Mascota Individual vs. Múltiples Animales (Clínica Veterinaria)
   - 9.3. Registro y Gestión de Fichas de Animales (Especie, Raza, Peso, Microchip, Alergias, Jaula/Box)
   - 9.4. Administración de Dosis, Notificaciones y Tratamientos Farmacológicos Veterinarios
10. [ASISTENTE VIRTUAL INTELIGENTE MIDI (IA GENERATIVA)](#10-asistente-virtual-inteligente-midi-ia-generativa)
    - 10.1. Acceso y Comunicación en Lenguaje Natural Bilingüe
    - 10.2. Consulta Dinámica de Medicamentos y Dosis del Día
    - 10.3. Agendamiento Conversacional de Tratamientos
    - 10.4. Digitalización de Fórmulas y Empaques mediante Visión Artificial
11. [MÓDULO DE ADHERENCIA TERAPÉUTICA Y REPORTES CLÍNICOS EN PDF](#11-módulo-de-adherencia-terapéutica-y-reportes-clínicos-en-pdf)
    - 11.1. Métricas e Indicadores Cuantitativos de Cumplimiento
    - 11.2. Generación y Exportación del Informe Clínico Oficial en PDF
12. [HERRAMIENTAS COMPLEMENTARIAS Y ACCESIBILIDAD](#12-herramientas-complementarias-y-accesibilidad)
    - 12.1. Modo Simplificado para Personas Mayores
    - 12.2. Asistencia por Voz (Lectura Text-to-Speech y Dictado)
    - 12.3. Localizador Georreferenciado de Farmacias en Mapa
    - 12.4. Widget para la Pantalla de Inicio de Android
13. [GUÍA DE OPTIMIZACIÓN DE BATERÍA POR FABRICANTE](#13-guía-de-optimización-de-batería-por-fabricante)
14. [PREGUNTAS FRECUENTES (FAQ) Y SOPORTE TÉCNICO](#14-preguntas-frecuentes-faq-y-soporte-técnico)

---

## 1. INTRODUCCIÓN Y PROPÓSITO DEL MANUAL

El presente documento constituye el **Manual de Usuario** oficial de la solución tecnológica **MediTime** en su versión **2.31.1**, desarrollada en el marco del Proyecto de Grado del programa de **Ingeniería de Sistemas y Computación** de la **Universidad de Cundinamarca, Seccional Ubaté**.

### 1.1. Propósito
El objetivo primordial de esta guía es orientar al usuario final (paciente, familiar o cuidador asistencial) en la correcta operación, parametrización y aprovechamiento de todas las funcionalidades ofrecidas por el aplicativo móvil. La plataforma ha sido diseñada con un enfoque centrado en la accesibilidad, la usabilidad y la confiabilidad, garantizando que personas de diversos grupos etarios puedan gestionar sus tratamientos médicos con total autonomía y precisión.

### 1.2. Alcance
El manual cubre de forma exhaustiva los procedimientos de autenticación, alta y administración de tratamientos farmacológicos, interacción con alarmas persistentes de alta prioridad, supervisión mediante el modo cuidador, diálogo con el asistente inteligente bilingüe **Midi**, consulta de métricas de adherencia y generación de reportes clínicos en formato PDF.

---

## 2. REQUISITOS DEL SISTEMA Y DISPOSITIVOS COMPATIBLES

Para asegurar un desempeño óptimo de los servicios en segundo plano y el correcto funcionamiento del motor de alarmas y almacenamiento en la nube, el dispositivo móvil debe satisfacer las siguientes especificaciones:

| Componente | Requisito Mínimo Recomendado |
| :--- | :--- |
| **Sistema Operativo:** | Android 8.0 (Oreo / API Level 26) o superior |
| **Memoria RAM:** | 2.0 GB de memoria física disponible |
| **Espacio de Almacenamiento:** | 100 MB libres para instalación y almacenamiento en caché de bases de datos locales |
| **Conectividad:** | Conexión a Internet (Wi-Fi, 4G o 5G) para sincronización inicial con Firebase y consultas a la IA Groq. (*Nota: Las alarmas programadas operan de manera 100% autónoma sin conexión a Internet*). |
| **Hardware Adicional:** | Cámara integrada (requerida para la captura y digitalización de fórmulas médicas y cajas de fármacos) y sensor GPS (para el localizador de farmacias). |

---

## 3. CONFIGURACIÓN INICIAL Y PERMISOS DEL SISTEMA OPERATIVO

Durante el primer inicio de MediTime, el sistema solicitará una serie de permisos indispensables. Es imperativo otorgar estas autorizaciones para garantizar que los recordatorios médicos se ejecuten puntualmente, incluso si el dispositivo se encuentra bloqueado o en modo de ahorro de energía.

### 3.1. Permiso de Alarmas y Recordatorios Exactos (`SCHEDULE_EXACT_ALARM`)
A partir de Android 12, el sistema operativo restringe por defecto el disparo de temporizadores precisos. MediTime requiere programar alarmas de hardware exactas mediante `AlarmManager` para garantizar que la dosis suene exactamente en el minuto programado. Al solicitarse en pantalla, se debe seleccionar **Permitir**.

### 3.2. Exclusión de la Optimización Agresiva de Batería
Los fabricantes implementan capas de software que suspenden procesos para ahorrar energía. Para que el servicio `alarm_callback_handler` despierte el teléfono a la hora programada, la aplicación debe ser excluida de la optimización de batería seleccionando la opción **"Sin restricciones"** o **"No optimizada"**.

### 3.3. Permisos de Cámara y Almacenamiento
Habilitan la captura fotográfica de fórmulas médicas para su análisis mediante visión artificial y la personalización de la foto de perfil del usuario o paciente.

### 3.4. Permiso de Ubicación (GPS)
Permite al módulo *Localizador de Farmacias* calcular la distancia y trazar la ruta hacia las droguerías más próximas al lugar donde se encuentra el usuario.

---

## 4. AUTENTICACIÓN Y PERFIL DE USUARIO

MediTime ofrece un entorno seguro para la protección de la información clínica y personal del paciente, cumpliendo con los estándares de seguridad y la legislación colombiana de protección de datos personales (Ley 1581 de 2012).

### 4.1. Registro de Nuevas Cuentas
1. En la pantalla inicial de bienvenida, se debe pulsar el enlace **"¿No tienes cuenta? Regístrate aquí"**.
2. Se solicitará el ingreso de los siguientes campos:
   - **Nombre completo:** Nombre y apellidos del usuario titular.
   - **Correo electrónico:** Dirección válida que funcionará como identificador único.
   - **Contraseña:** Clave de acceso con un mínimo de 6 caracteres alfanuméricos.
   - **Confirmación de contraseña:** Verificación para evitar errores tipográficos.
3. Se debe presionar el botón **"Registrarse"**. El sistema creará la cuenta y enviará una confirmación automática.

### 4.2. Inicio de Sesión Estándar y Acceso Federado con Google
El usuario dispone de dos mecanismos de autenticación:
- **Autenticación estándar:** Ingrese el correo electrónico y contraseña registrados, y pulse **"Iniciar Sesión"**.
- **Google Sign-In:** Pulse el botón **"Continuar con Google"**. Se desplegará el diálogo seguro de Google Play Services permitiendo la autenticación en un solo toque mediante la cuenta configurada en el dispositivo móvil.

### 4.3. Recuperación de Credenciales de Acceso
En caso de extravío de la contraseña:
1. En la pantalla de ingreso, seleccione la opción **"¿Olvidaste tu contraseña?"**.
2. Ingrese el correo electrónico vinculado a la cuenta de usuario.
3. Pulse **"Enviar enlace de restablecimiento"**. Se remitirá un mensaje seguro a la bandeja de entrada para definir una nueva clave.

### 4.4. Diligenciamiento y Actualización del Perfil Médico
MediTime integra una ficha clínica personal fundamental para situaciones de emergencia:
1. Despliegue el menú lateral (icono de tres barras o *drawer*) y seleccione **"Mi Perfil"**.
2. Pulse el botón de edición para actualizar los siguientes rubros:
   - **Foto de perfil:** Permite capturar una foto instantánea o cargarla desde la galería del dispositivo.
   - **Fecha de nacimiento:** Cálculo automático de la edad cronológica.
   - **Tipo de sangre:** Selección entre las clasificaciones estándar (A+, A-, B+, B-, AB+, AB-, O+, O-).
   - **Alergias conocidas:** Registro de contraindicaciones y alergias farmacológicas (ej. Penicilina, AINEs).
   - **Antecedentes clínicos:** Diagnósticos preexistentes (ej. Hipertensión arterial, Diabetes Mellitus Tipo 2).
   - **Contacto de emergencia:** Nombre y número de teléfono de contacto para auxilio inmediato.
3. Presione el botón **"Guardar Cambios"** para sincronizar la información con Cloud Firestore.

### 4.5. Tutorial Interactivo Guiado (Showcase)
Al ingresar a la aplicación por primera vez, el sistema activa de forma automática una secuencia de orientación interactiva (*Showcase View*). Esta herramienta resalta visualmente los elementos primordiales de la pantalla principal (menú de navegación, botón flotante de nueva receta, asistente Midi, tarjeta de resumen y calendario) con globos explicativos. El usuario puede seguir las indicaciones paso a paso o pulsar el botón **"Saltar"** en cualquier instante.

---

## 5. GESTIÓN INTEGRAL DE TRATAMIENTOS Y MEDICAMENTOS

Este módulo constituye el núcleo operativo de MediTime. Permite la programación detallada de regímenes posológicos, controlando cantidades, horarios y existencias.

### 5.1. Registro y Alta de un Tratamiento Farmacológico
1. Desde la pantalla principal (*Home*), presione el botón flotante circular con el símbolo **"+"** ubicado en el extremo inferior derecho.
2. Ingrese el **Nombre del Medicamento** (ej. *Metformina*, *Losartán*, *Amoxicilina*).
3. Seleccione la **Presentación farmacéutica**:
   - Tabletas / Comprimidos
   - Jarabe / Solución oral (ml)
   - Gotas
   - Cápsulas
   - Inyección / Ampolla
   - Inhalador / Aerosol
   - Parche transdérmico

### 5.2. Selección de Presentación, Dosis e Intervalos Horarios
- **Dosis por toma:** Indique el número de unidades a consumir en cada evento (ej. *1 tableta*, *5 ml*).
- **Hora de la primera dosis:** Utilice el selector circular de tiempo (*TimePickerSpinner*) para establecer la hora inicial del tratamiento.
- **Intervalo entre dosis:** Especifique el tiempo de recurrencia en horas (ej. cada 6, 8, 12 o 24 horas). El sistema calculará automáticamente todos los horarios subsecuentes del día.

### 5.3. Tratamientos Continuos o Indefinidos (Patologías Crónicas)
Para pacientes que requieren medicación de uso permanente:
1. En el selector de duración, active la casilla de verificación **"Tratamiento Continuo / Indefinido"**.
2. Al activar esta modalidad, MediTime desplegará el motor de carga bajo demanda (*Lazy Loading*). El sistema no sobrecargará la memoria del teléfono creando miles de dosis futuras estáticas; en su lugar, proyectará las tomas en tiempo real a medida que el usuario navega por las fechas del calendario.

### 5.4. Control de Inventario y Alerta Preventiva de Stock Bajo
MediTime incorpora un algoritmo de control de existencias farmacéuticas:
- **Cantidad total de la caja:** Número total de unidades adquiridas en el empaque (ej. caja de 30 comprimidos).
- **Cantidad actual disponible:** Existencias al momento de crear o editar la receta.
- **Detección automática de stock bajo:** Cuando el inventario desciende por debajo del **20%** de la capacidad del empaque o quedan **menos de 5 dosis**, el sistema emite una alerta visual en la tarjeta del medicamento y envía una notificación recordando adquirir una nueva prescripción antes de que se agote.

### 5.5. Consulta, Edición, Suspensión y Eliminación de Recetas
- **Ver detalle:** Al pulsar sobre cualquier tarjeta en la pantalla principal o lista de medicamentos, se presenta el desglose posológico, el porcentaje de tomas cumplidas y el inventario disponible.
- **Modificación:** Presione el icono de lápiz para editar horarios, notas médicas o dosis.
- **Eliminación y Revocación:** Si un tratamiento finaliza anticipadamente o es cancelado por el médico, pulse el botón de papelera. MediTime cancelará de inmediato todas las alarmas programadas en el hardware del sistema a través del método `cancelTreatmentAlarms()`.

---

## 6. SISTEMA DE RECORDATORIOS, NOTIFICACIONES Y ALARMAS

El motor de alertas de MediTime ha sido diseñado para funcionar de manera ininterrumpida bajo la arquitectura *Offline-First*.

### 6.1. Modalidades de Notificación
El usuario puede parametrizar el comportamiento de las alertas ingresando a **Opciones > Configuración de Notificaciones**:

1. **Modo Alarma (Recomendado):** Al llegar el horario exacto, el teléfono se activa con una pantalla completa (*AlarmRingingPage*), encendiendo la pantalla aun si el dispositivo está bloqueado, reproduciendo un tono sonoro continuo y activando la vibración insistente.
2. **Modo Activo:** Muestra una notificación emergente (*Heads-Up Notification*) de alta prioridad en la barra superior con botones de acción directa.
3. **Modo Pasivo / Automático:** Notificación informativa que registra la dosis como tomada de forma automática para personas con horarios estrictos sin necesidad de confirmación manual.

### 6.2. Pantalla de Alarma Persistente y Acciones Rápidas
Cuando se activa el Modo Alarma, la interfaz despliega de forma prominente el nombre del fármaco, la cantidad a ingerir, la indicación y tres botones ergonómicos de gran tamaño:

| Botón de Acción | Efecto en el Sistema |
| :--- | :--- |
| **TOMAR (Verde)** | Detiene el sonido de alarma. Deduce la dosis del inventario actual en el dispositivo y en Cloud Firestore. Marca el estado de la dosis como **Tomada** con el registro temporal exacto. |
| **POSPONER (Amarillo / Snooze)** | Silencia momentáneamente la alarma y programa un nuevo recordatorio tras cumplirse el intervalo de gracia configurado (ej. 10 o 15 minutos). La dosis se marca temporalmente como **Aplazada**. |
| **OMITIR (Rojo)** | Silencia la alarma. Registra en el historial clínico que la dosis no fue consumida (estado **Omitida**), permitiendo documentar las razones ante el médico tratante. |

### 6.3. Configuración de Tiempos de Aplazamiento y Tonos
En la sección de ajustes, se puede personalizar:
- **Tiempo de aplazamiento:** Selección de intervalos de 5, 10, 15, 20 o 30 minutos.
- **Tono de timbre:** Selección entre alarmas melódicas suaves o tonos de alta frecuencia sonora mediante el servicio `AlarmSoundService`.
- **Patrón de vibración:** Activar o desactivar la pulsación vibratoria rítmica.

---

## 7. CALENDARIO INTERACTIVO Y REGISTRO CRONOLÓGICO

MediTime incorpora un visor de calendario mensual interactivo (`TableCalendar`) que ofrece trazabilidad visual y temporal sobre la ingesta farmacológica.

### 7.1. Vista Mensual y Diaria
- En la pestaña inferior **"Calendario"**, se expone el mes en curso.
- Los días que cuentan con tomas programadas exhiben indicadores visuales circulares.
- Al presionar cualquier fecha específica, la parte inferior despliega la lista cronológica de las dosis programadas para ese día con su respectiva hora y estado.

### 7.2. Código Cromático de Estados de Dosis
Para una identificación rápida y universal, los estados de cada toma se distinguen mediante la siguiente convención de colores:

| Estado | Color Asociado | Significado Clínico |
| :--- | :--- | :--- |
| **Pendiente** | Gris (`#9E9E9E`) | Toma futura o pendiente en el transcurso de la jornada. |
| **Notificada** | Ámbar / Amarillo (`#FFC107`) | La alarma ya sonó y se encuentra a la espera de la interacción del paciente. |
| **Tomada** | Verde Esmeralda (`#4CAF50`) | El medicamento fue consumido satisfactoriamente. |
| **Omitida** | Carmesí / Rojo (`#F44336`) | El paciente decidió saltarse la toma o no pudo ingerirla. |
| **Aplazada** | Naranja Intenso (`#FF9800`) | La toma fue pospuesta temporalmente para un horario posterior. |

### 7.3. Auditoría y Registro Retrospectivo
El usuario puede seleccionar días pasados para verificar el cumplimiento histórico. Si por olvido involuntario el paciente consumió su dosis sin confirmarla en la pantalla de alarma en su momento, el sistema permite marcar retrospectivamente la casilla de verificación desde la lista diaria, actualizando las estadísticas globales de adherencia.

---

## 8. MODO CUIDADOR (FAMILIAR Y ASISTENCIAL / CLÍNICO)

El Modo Cuidador es una funcionalidad innovadora orientada a personas que tienen bajo su responsabilidad la administración y supervisión farmacológica de familiares dependientes o pacientes institucionalizados.

### 8.1. Gestión Multi-Paciente y Perfiles Dependientes
1. Desde el menú lateral, seleccione **"Modo Cuidador"**.
2. Presione el botón **"Gestionar Perfiles"** o el botón flotante **"+"** para crear un nuevo sujeto de cuidado.
3. Ingrese el nombre del paciente, su edad aproximada y el parentesco o vínculo.
4. Asigne un **color identificador** exclusivo. Este color servirá de marco y etiqueta en todas las tarjetas de tratamiento y notificaciones correspondientes a este paciente, evitando cualquier confusión en hogares con múltiples tratamientos.

### 8.2. Modalidad Familiar vs. Modalidad Clínica
- **Modalidad Familiar:** Diseñada para entornos domésticos con interfaz simplificada y nombres familiares (ej. *"Tratamiento de la Abuela Carmen"*).
- **Modalidad Clínica:** Concebida para hogares geriátricos, clínicas o enfermeros particulares:
  - **Número de habitación / Cama:** Permite registrar la ubicación espacial del paciente (ej. *Cama 204-B*).
  - **Categoría o Piso:** Permite agrupar a los pacientes por alas hospitalarias o niveles para facilitar rondas de medicación.
  - **Notas especiales:** Espacio para consignar dietas especiales, restricciones de deglución o precauciones.

### 8.3. Vinculación Remota de Cuentas
MediTime permite vincular perfiles locales con cuentas reales de Firebase mediante la dirección de correo electrónico (`linkedUid`). De este modo, cuando el cuidador programa una receta en su propio teléfono, esta se replica automáticamente en el dispositivo del paciente, o viceversa, garantizando supervisión a distancia en tiempo real.

---

## 9. MODO ANIMALES Y VETERINARIA (GESTIÓN DE MASCOTAS Y CLÍNICAS VETERINARIAS)

El **Modo Animales (Veterinaria)** es un módulo adaptativo de vanguardia diseñado para propietarios de mascotas, refugios, rescatistas y profesionales de clínicas y centros veterinarios, permitiendo gestionar tratamientos farmacológicos en animales con exactitud posológica, personalización zootécnica y una interfaz de usuario completamente adaptada.

### 9.1. Activación y Adaptación Visual Dinámica (Tema Verde Veterinario)
1. Ingrese a la sección **"Ajustes y Opciones"** desde el menú principal y seleccione la tarjeta **"Modo Animales (Veterinaria)"**.
2. Active el interruptor **"Habilitar Modo Animales"**.
3. **Transformación cromática instantánea:** MediTime transformará de manera inmediata y reactiva toda la paleta de colores de la aplicación, sustituyendo el azul clínico tradicional por una gama armónica de **Verde Esmeralda Médico (`#15803D`)** y **Verde Bosque Oscuro (`#047857`)**, con gradientes biológicos, fondos claros u oscuros optimizados y superficies de contraste accesible. Al desactivar el modo, la aplicación restaura automáticamente la identidad azul estándar.
4. **Distintivos visuales en el sistema:** El cajón de navegación lateral (*Drawer*) expone la insignia destacada **`🐾 Modo Animales`**, habilitando accesos directos exclusivos para la gestión veterinaria.

### 9.2. Modalidades: Mascota Individual vs. Múltiples Animales (Clínica Veterinaria)
El usuario puede alternar entre dos filosofías operativas según su rol o contexto:
- **Mascota Individual (Hogar / Propietario Único):** Optimiza la experiencia para el cuidado de un animal de compañía principal. La pantalla de inicio y los recordatorios priorizan los tratamientos de dicha mascota sin requerir filtros complejos.
- **Múltiples Animales (Clínica Veterinaria / Refugio / Guardería):** Permite administrar simultáneamente decenas de pacientes veterinarios, hospitalizaciones y tratamientos paralelos. Incorpora el selector rápido de pacientes animales en la barra superior con el icono distintivo de huella (`Icons.pets_rounded`), facilitando rondas médicas veterinarias y alternancia entre fichas clínicas individuales o la vista general unificada.

### 9.3. Registro y Gestión de Fichas de Animales
Al registrar o editar un perfil en Modo Animales, el formulario se transforma para recopilar variables zootécnicas críticas:
- **Nombre de la Mascota / Paciente:** Nombre común o identificador del animal.
- **Especie Animal:** Selector directo con especies comunes (*Perro/Canino, Gato/Felino, Ave, Conejo, Equino, Bovino, Roedor, Réptil*) u opción personalizada.
- **Raza:** Permite documentar la raza o cruce genético específico del ejemplar.
- **Peso Corporal:** Registro del peso (ej. *14.5 kg* o *3.2 kg*), esencial para el cálculo y auditoría de dosificaciones veterinarias dependientes de la masa del animal.
- **Número de Microchip / Tatuaje:** Código único de identificación electrónica oficial del animal para trazabilidad legal e institucional.
- **Ubicación Clínica / Jaula / Box:** Identificador de jaula, canil o box de hospitalización en entornos veterinarios.
- **Alergias y Notas Zootécnicas:** Registro de intolerancias alimentarias o medicamentosas, condiciones conductuales y antecedentes clínicos.

### 9.4. Administración de Dosis, Notificaciones y Tratamientos Farmacológicos Veterinarios
- **Asociación en Fórmulas Médicas:** Al registrar una nueva receta médica, el paso inicial permite asociar el tratamiento directamente al paciente veterinario correspondiente, exhibiendo sus datos de especie, raza y peso.
- **Alertas y Notificaciones Adaptadas:** Los recordatorios de alarmas y notificaciones señalan explícitamente el nombre de la mascota y la dosis formulada, previniendo equivocaciones en hogares o clínicas donde conviven múltiples especies.
- **Control de Inventario Veterinario:** Permite llevar control estricto de tabletas, jarabes, gotas óticas/oftálmicas, pastas orales y pomadas tópicas para animales.

---

## 10. ASISTENTE VIRTUAL INTELIGENTE MIDI (IA GENERATIVA)

MediTime integra a **Midi**, un asistente de inteligencia artificial bilingüe de última generación, impulsado por modelos avanzados de lenguaje (LLM) a través de la API ultrarrápida de Groq Cloud.

### 10.1. Acceso y Comunicación en Lenguaje Natural Bilingüe
- Se accede a Midi pulsando el icono animado del asistente en la esquina superior de la pantalla principal o desde el menú lateral.
- **Avatar con animación biológica:** Midi cuenta con un diseño amigable que parpadea periódicamente de forma natural simulando atención activa.
- **Bilingüismo transparente:** El usuario puede redactar sus consultas indistintamente en **español** o **inglés**. Midi detectará el idioma de forma automática y responderá en el mismo idioma con fluidez y empatía.

### 10.2. Consulta Dinámica de Medicamentos y Dosis del Día
Midi no es un simple generador de texto; cuenta con capacidades de ejecución de herramientas (*Function Calling / Tool Calling*). Puede consultar en tiempo real las bases de datos de tratamientos del usuario:
- *Ejemplo de consulta:* "¿Cuáles son mis medicamentos de hoy?"
- *Comportamiento:* Midi ejecuta internamente la función `get_today_medications`, analiza el estado de cada dosis y responde:
  > *"Hoy tienes programadas 3 tomas: a las 8:00 AM ya tomaste tu **Losartán**, a las 2:00 PM tienes pendiente tu **Amoxicilina**, y a las 8:00 PM debes volver a tomar **Losartán**. ¿Deseas que revise tu inventario?"*

### 10.3. Agendamiento Conversacional de Tratamientos
El paciente puede solicitar el alta de un tratamiento hablándole o escribiéndole directamente al asistente:
- *Ejemplo:* *"Midi, el médico me formuló Ibuprofeno de 400 mg cada 8 horas por 5 días empezando hoy a las 2 de la tarde."*
- *Comportamiento:* Midi invoca la herramienta interna `create_treatment`, estructura los parámetros y crea la receta y sus respectivas alarmas en el sistema sin que el usuario deba diligenciar formularios manuales.

### 10.4. Digitalización de Fórmulas y Empaques mediante Visión Artificial
Mediante el icono de cámara presente en la barra de chat de Midi:
1. El usuario puede capturar una fotografía de una fórmula médica manuscrita o del empaque comercial de un fármaco.
2. El modelo de visión artificial multimodal de MediTime (`qwen/qwen3.6-27b`) procesa la imagen, extrae el principio activo, la concentración y las instrucciones de posología, y le sugiere al usuario la configuración de su tratamiento para confirmación en un solo toque.

---

## 11. MÓDULO DE ADHERENCIA TERAPÉUTICA Y REPORTES CLÍNICOS EN PDF

El seguimiento riguroso del cumplimiento farmacológico es esencial para el éxito de cualquier tratamiento médico o veterinario. MediTime proporciona herramientas estadísticas avanzadas y generación de informes certificados.

### 11.1. Métricas e Indicadores Cuantitativos de Cumplimiento
En la sección **"Progreso y Reportes"**, el usuario puede visualizar:
- **Tasa de Adherencia Global:** Porcentaje matemático calculado como el cociente entre el número de dosis tomadas y el total de dosis programadas multiplicado por cien.
- **Gráficos interactivos:** Gráficos de anillo y barras de cumplimiento temporal (`fl_chart`), con desglose específico por cada fármaco prescrito.

### 11.2. Generación y Exportación del Informe Clínico Oficial en PDF
1. Presione el botón **"Generar Reporte PDF"** en la pantalla de reportes.
2. Seleccione el periodo de análisis deseado: última semana, último mes o rango personalizado.
3. El servicio `PdfReportService` compilará un documento formal en formato A4 con encabezado institucional, logotipo de MediTime, datos del paciente o animal, resumen numérico, gráfica renderizada y tabla de auditoría por tratamiento.
4. El visor integrado de impresión permite:
   - Guardar el documento como archivo PDF en la memoria interna del teléfono.
   - Compartir instantáneamente el PDF por WhatsApp, correo electrónico o Telegram con el médico especialista, médico veterinario o familiar responsable.
   - Enviar a una impresora inalámbrica Wi-Fi.

---

## 12. HERRAMIENTAS COMPLEMENTARIAS Y ACCESIBILIDAD

Para garantizar la inclusión de personas en condición de vulnerabilidad motriz o sensorial, MediTime integra tecnologías asistivas de vanguardia.

### 12.1. Modo Simplificado para Personas Mayores
En **Opciones > Accesibilidad**, es posible activar la opción **"Modo Simplificado"**:
- Incrementa automáticamente el tamaño de fuente tipográfica y el contraste visual.
- Simplifica la pantalla principal ocultando gráficos complejos y dejando únicamente las tarjetas de la próxima dosis con botones grandes y leyendas en alto contraste.

### 12.2. Asistencia por Voz (Text-to-Speech y Comandos)
- **Lectura auditiva:** Al presionar el icono de altavoz en cualquier tratamiento, el motor sintetizador `flutter_tts` vocaliza en español claro la dosis, la forma de ingesta y las notas médicas.
- **Grabación y dictado:** Permite registrar notas posológicas dictando la voz mediante el plugin nativo `record`.

### 12.3. Localizador Georreferenciado de Farmacias en Mapa
1. Ingrese a la opción **"Localizador de Farmacias"** desde el menú principal.
2. La aplicación utiliza el GPS del teléfono (`geolocator`) y carga un mapa vectorial dinámico (`maplibre_gl`).
3. Se despliegan marcadores visuales señalando droguerías, farmacias y puntos de atención médica cercanos en el municipio o provincia, con opción de pulsar sobre ellas para obtener la ruta de desplazamiento o el número de contacto telefónico.

### 12.4. Widget para la Pantalla de Inicio de Android
MediTime incluye un componente interactivo para el escritorio del teléfono móvil mediante `home_widget`:
1. Mantenga pulsado un espacio libre en la pantalla de inicio de su teléfono Android.
2. Seleccione **Widgets > MediTime**.
3. Arrastre el widget al escritorio. Este mostrará permanentemente el nombre, dosis y hora de su siguiente medicamento programado sin necesidad de abrir la aplicación.

---

## 13. GUÍA DE OPTIMIZACIÓN DE BATERÍA POR FABRICANTE

Diversas capas de personalización del sistema operativo Android implementan gestores de energía excesivamente agresivos que pueden suspender el servicio de alarmas. MediTime incluye una guía paso a paso accesible desde **Opciones > Guía de Optimización**:

### 13.1. Dispositivos Xiaomi / Redmi / POCO (MIUI / HyperOS)
1. Ingrese a **Ajustes > Aplicaciones > Administrar aplicaciones > MediTime**.
2. Active la casilla de **Inicio Automático** (*Autostart*).
3. En **Ahorro de Batería**, elija la opción **"Sin Restricciones"**.
4. En **Otros Permisos**, conceda: "Mostrar en pantalla de bloqueo", "Mostrar ventanas emergentes mientras se ejecuta en segundo plano" y "Notificaciones permanentes".

### 13.2. Dispositivos Samsung (One UI)
1. Diríjase a **Ajustes > Aplicaciones > MediTime > Batería**.
2. Seleccione la opción **"No optimizada"** o **"Sin restricciones"**.
3. En **Ajustes > Cuidado del dispositivo > Batería > Límites de uso en segundo plano**, verifique que MediTime figure en la lista de **"Aplicaciones que nunca entran en suspensión"**.

### 13.3. Dispositivos Huawei (EMUI)
1. Acceda a **Ajustes > Batería > Inicio de aplicaciones**.
2. Localice MediTime, desactive el modo automático y en la ventana emergente active manualmente: **"Inicio automático"**, **"Inicio secundario"** y **"Ejecutar en segundo plano"**.

---

## 14. PREGUNTAS FRECUENTES (FAQ) Y SOPORTE TÉCNICO

### ¿Las alarmas sonarán si el teléfono móvil está apagado?
No. Ninguna aplicación de software puede ejecutar procesos si el circuito de hardware está completamente desprovisto de energía. No obstante, en cuanto el dispositivo sea encendido o reiniciado, el receptor `RECEIVE_BOOT_COMPLETED` de MediTime reactivará automáticamente todas las alarmas en el hardware sin que el usuario deba abrir la app.

### ¿Qué sucede si me encuentro en una zona rural sin cobertura de internet?
MediTime opera bajo el principio **Offline-First**. Las alarmas, el calendario, el registro de tomas y las alertas de stock funcionan con normalidad sin señal de telefonía o Wi-Fi. Las funciones dependientes de internet son el asistente de IA Midi, el mapa de farmacias y la sincronización con la nube de Firebase, las cuales sincronizarán sus datos pendientes en cuanto se restablezca la conectividad.

### ¿Puedo tener la cuenta de mi madre abierta en mi celular y en el de ella al mismo tiempo?
Sí. Gracias a la infraestructura de Cloud Firestore, la información de tratamientos y el registro de tomas se sincronizan en tiempo real entre múltiples dispositivos vinculados a la misma cuenta o asociados a través del Modo Cuidador.

### ¿El Modo Animales permite gestionar tratamientos tanto para perros y gatos como para ganado o caballos?
Sí. El sistema incluye un catálogo zootécnico amplio (caninos, felinos, equinos, bovinos, aves, conejos, roedores y reptiles) y la posibilidad de registrar especies personalizadas con su peso en kilogramos, raza, número de microchip y jaula o box de estabulación.

---

### Canales de Soporte Académico y Técnico
- **Entidad Responsable:** Proyecto de Grado MediTime - Facultad de Ingeniería.
- **Universidad:** Universidad de Cundinamarca, Seccional Ubaté.
- **Contacto de Desarrolladores:**
  - Jorge Eliecer Delgado Cortés (`jdkinior@gmail.com`)
  - Johan Alexander Arévalo Contreras
- **Repositorio Oficial:** `https://github.com/JDkinior/MediTime`
