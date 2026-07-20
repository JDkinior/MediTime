# MediTime Chatbot — Reestructuración Completa

Plan de mejoras para resolver los 6 problemas reportados y elevar la calidad del chatbot a nivel profesional.

---

## Diagnóstico Actual

Después de una investigación exhaustiva del código, estos son los problemas raíz:

| # | Problema | Causa Raíz |
|---|----------|------------|
| 1 | Error 413 (Request too large) | System prompt (~750 palabras) + TODAS las dosis de tratamientos activos + 12 mensajes de historial = **7000-10000+ tokens** por request, superando el límite de 6000 TPM del free tier |
| 2 | Respuestas inexactas sobre medicamentos del día | Se vuelcan TODOS los datos de tratamientos en el prompt (incluyendo dosis futuras y pasadas sin filtrar por hoy). El modelo "adivina" en vez de consultar datos filtrados |
| 3 | Tags de acción visibles en el chat | Durante el streaming, tags parciales como `<create_treatme` aparecen antes de poder hacer regex match. No hay buffer de retención |
| 4 | Tokens excesivos | Sin `max_tokens` configurado + system prompt enorme + contexto de tratamiento en CADA mensaje + historial de 12 mensajes |
| 5 | No hay chat de voz | Falta implementación de STT/TTS |
| 6 | Funcionalidades a perfeccionar | Sin function calling nativo; acciones basadas en tags XML frágiles |

---

## Propuesta de Cambios

### Componente 1: Optimización de Tokens y Modelo (Problemas #1 y #4)

#### [MODIFY] [gemini_service.dart](file:///c:/Users/degkp/Documents/Proyectos/MediTime/lib/services/gemini_service.dart)

**Cambios clave:**
1. **Cambiar modelo** de `llama-3.1-8b-instant` (6,000 TPM) → `gemma2-9b-it` (15,000 TPM) — 2.5x más tokens disponibles, misma calidad para tareas de chat
2. **Agregar `max_completion_tokens: 400`** para limitar respuestas a ~300 palabras máximo
3. **Reducir historial** de 12 a 6 mensajes (3 turnos de conversación)
4. **Comprimir system prompt** — eliminar explicaciones redundantes, mantener solo reglas esenciales (~300 palabras vs ~750 actuales)
5. **Extraer el contexto de tratamientos del system prompt** — mover a function calling (ver Componente 3)
6. **Implementar estimación de tokens** antes de enviar — si se acerca al límite, resumir historial

> [!IMPORTANT]
> El cambio a `gemma2-9b-it` proporciona 15,000 TPM en free tier (2.5x más). Sin embargo, tiene context window de 8,192 tokens vs 128K de llama. Con las optimizaciones de prompt y function calling, 8K es más que suficiente para un chatbot médico. Si prefieres mantener 128K de contexto, la alternativa es `llama-3.3-70b-versatile` con 12,000 TPM pero solo 1,000 RPD (requests por día).

---

### Componente 2: Precisión de Datos de Medicamentos (Problema #2)

#### [MODIFY] [gemini_service.dart](file:///c:/Users/degkp/Documents/Proyectos/MediTime/lib/services/gemini_service.dart)

**Cambios clave:**
1. **Implementar Groq Function Calling nativo** en vez de tags XML. Definir herramientas (tools):
   - `get_today_medications` — Retorna SOLO medicamentos programados para hoy con horarios exactos
   - `get_tomorrow_medications` — Retorna medicamentos de mañana
   - `get_active_treatments_summary` — Resumen de tratamientos activos (nombre, dosis, frecuencia)
   - `create_treatment` — Crear un nuevo tratamiento
   - `update_dose_status` — Marcar dosis como tomada/omitida/aplazada
   - `show_adherence_chart` — Mostrar gráfico de adherencia
   - `get_treatment_inventory` — Consultar stock de medicamentos
2. **El modelo ya no recibe datos de tratamientos en cada mensaje** — solo los consulta cuando los necesita via function calling
3. **Filtrado preciso por fecha** — la función `get_today_medications` filtra `doseStatus` solo para el día actual, eliminando confusión con días futuros/pasados

#### [MODIFY] [chat_bot_screen.dart](file:///c:/Users/degkp/Documents/Proyectos/MediTime/lib/screens/chat/chat_bot_screen.dart)

**Cambios clave:**
1. **Eliminar parsing de tags XML** — ya no se necesitan regex para `<create_treatment>`, `<update_dose>`, `<show_adherence_chart/>`
2. **Implementar loop de function calling** — cuando el modelo responde con `tool_calls`, ejecutar la función, enviar resultado de vuelta, y obtener respuesta final
3. **Las acciones se ejecutan automáticamente** como parte del loop de function calling, sin necesidad de tags en el texto

---

### Componente 3: Eliminación de Tags Visibles (Problema #3)

Este problema se resuelve **completamente** con el Componente 2. Al usar function calling nativo de Groq:
- El modelo responde con un campo `tool_calls` en el JSON (separado del `content`)
- Nunca aparecen tags en el texto visible
- No hay posibilidad de tags parciales durante streaming
- El flujo es: modelo → tool_call → ejecución → resultado → respuesta final limpia al usuario

---

### Componente 4: Chat de Voz (Problema #5)

#### [NEW] [voice_service.dart](file:///c:/Users/degkp/Documents/Proyectos/MediTime/lib/services/voice_service.dart)

**Pipeline de voz usando Groq STT + TTS on-device:**
1. **STT (Speech-to-Text)**: Usar la API de **Groq Whisper** (`whisper-large-v3-turbo`) — NO consume tokens LLM, tiene su propio rate limit separado (20 RPM, 2000 audio-seconds/hour gratis)
2. **TTS (Text-to-Speech)**: Usar **`flutter_tts`** — TTS nativo del dispositivo, sin costo, sin API, buena calidad en español
3. **Grabación de audio**: Usar **`record`** package para capturar audio del micrófono y enviarlo a Groq Whisper

**Flujo de voz:**
```
Usuario habla → record captura audio WAV
→ Envía a Groq Whisper API (transcripción)
→ Texto transcrito se envía al LLM (streamResponse)
→ Respuesta del LLM se reproduce con flutter_tts
```

#### [MODIFY] [chat_bot_screen.dart](file:///c:/Users/degkp/Documents/Proyectos/MediTime/lib/screens/chat/chat_bot_screen.dart)

**Cambios UI para voz:**
1. Agregar botón de micrófono en el composer (al lado del botón de enviar)
2. Cuando se presiona, mostrar overlay de grabación con animación de onda
3. Al soltar o detectar silencio, enviar audio a Groq Whisper
4. Mostrar texto transcrito como mensaje del usuario
5. La respuesta del LLM se reproduce automáticamente con TTS
6. Toggle para activar/desactivar lectura de respuestas en voz alta

#### [MODIFY] [AndroidManifest.xml](file:///c:/Users/degkp/Documents/Proyectos/MediTime/android/app/src/main/AndroidManifest.xml)

- Agregar permiso `RECORD_AUDIO`

#### [MODIFY] [pubspec.yaml](file:///c:/Users/degkp/Documents/Proyectos/MediTime/pubspec.yaml)

- Agregar dependencias: `flutter_tts`, `record`, `path_provider` (para archivos de audio temporales)

---

### Componente 5: Perfeccionamiento de Funcionalidades (Problema #6)

#### Herramientas de Function Calling a implementar:

| Herramienta | Descripción | Ejemplo de uso |
|-------------|-------------|----------------|
| `get_today_medications` | Medicamentos programados hoy con horarios y estados | "¿Qué medicamentos tengo hoy?" |
| `get_tomorrow_medications` | Medicamentos programados mañana | "¿Qué tomo mañana?" |
| `get_active_treatments_summary` | Resumen de todos los tratamientos activos | "¿Cuáles son mis tratamientos?" |
| `create_treatment` | Crear nuevo tratamiento/recordatorio | "Agrégame paracetamol cada 8h" |
| `update_dose_status` | Marcar dosis como tomada/omitida/aplazada | "Ya me tomé el ibuprofeno" |
| `show_adherence_chart` | Mostrar gráfico de adherencia inline | "¿Cómo va mi progreso?" |
| `get_treatment_inventory` | Consultar stock de medicamentos | "¿Cuántas pastillas me quedan?" |
| `get_missed_doses` | Ver dosis omitidas recientes | "¿He olvidado alguna dosis?" |

#### Nuevas funcionalidades sugeridas:

1. **Buffer de streaming inteligente** — Retener tokens durante streaming hasta completar una frase/párrafo para mejor legibilidad
2. **Manejo de errores mejorado** — Mensajes de error más amigables y específicos, con sugerencias de acción
3. **Indicador de tokens** — Mostrar uso de tokens discretamente para que el usuario sea consciente
4. **Respuestas más concisas** — Instruir al modelo para respuestas de máximo 3-4 oraciones en conversación casual
5. **Cache de system prompt** — Groq automáticamente cachea prefijos comunes, lo cual ya reducirá TPM

---

## Arquitectura Propuesta

```
┌─────────────────────────────────────────┐
│         ChatBotScreen (UI Layer)        │
│  - Gestión de estado + Voice UI         │
│  - Function calling loop                │
│  - Renderizado de burbujas + widgets    │
└──────┬──────────────────┬───────────────┘
       │                  │
┌──────▼──────┐    ┌──────▼──────────┐
│ GeminiService│    │  VoiceService   │
│ (Optimizado) │    │  - STT (Groq)   │
│ - Function   │    │  - TTS (native) │
│   Calling    │    │  - Audio record │
│ - Token mgmt │    └─────────────────┘
└──────┬───────┘
       │
┌──────▼──────────────┐
│  Groq API           │
│  - gemma2-9b-it     │
│  - whisper-v3-turbo │
│  - Tool Use API     │
└─────────────────────┘
```

---

## Open Questions

> [!IMPORTANT]
> **Modelo preferido**: ¿Prefieres `gemma2-9b-it` (15,000 TPM, 8K context) o `llama-3.3-70b-versatile` (12,000 TPM, 128K context, más inteligente pero solo 1,000 requests/día)? Mi recomendación es `gemma2-9b-it` por su mayor cuota de tokens.

> [!IMPORTANT]
> **TTS del chatbot**: ¿Quieres que TODAS las respuestas se lean en voz alta automáticamente (como el modo voz de ChatGPT), o que solo se lean cuando el usuario envía un mensaje de voz? Mi recomendación es que solo se lean las respuestas cuando el usuario usa voz, con un toggle global para activar/desactivar.

> [!IMPORTANT]
> **Interfaz de voz**: ¿Prefieres un modo de voz con overlay completo (como ChatGPT voice mode — pantalla completa con animación) o un botón inline en el composer (más sutil, como WhatsApp voice messages)?

> [!WARNING]
> **Dependencias nuevas**: Se necesitan 3 paquetes nuevos: `flutter_tts`, `record`, `path_provider`. ¿Está bien agregar estas dependencias? Son paquetes estables y bien mantenidos.

---

## Plan de Verificación

### Pruebas Automatizadas
```bash
flutter analyze
flutter build apk --debug --dart-define=GROQ_API_KEY=YOUR_KEY
```

### Verificación Manual
1. **Tokens**: Enviar 5+ mensajes seguidos sin error 413
2. **Precisión**: Preguntar "¿qué medicamentos tengo hoy?" y verificar que SOLO muestre los del día actual
3. **Tags**: Verificar que no aparezcan tags XML/HTML en ningún mensaje
4. **Voz**: Grabar mensaje de voz, verificar transcripción correcta, verificar reproducción de respuesta
5. **Function calling**: Pedir crear medicamento, marcar dosis, ver progreso — verificar que cada acción se ejecute correctamente
6. **Rate limits**: Conversación sostenida de 10+ mensajes sin alcanzar límite

### Métricas de Éxito
- ✅ 0 errores 413 en uso normal
- ✅ 100% precisión en medicamentos del día actual
- ✅ 0 tags visibles en respuestas
- ✅ ~200-400 tokens por respuesta (vs. ilimitado actual)
- ✅ Chat de voz funcional con STT + TTS
- ✅ Function calling para todas las acciones
