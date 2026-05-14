# MediTime Chatbot - Documentación Técnica

## 📋 Descripción General

El módulo de chatbot de **MediTime** implementa un asistente de IA bilingüe (español/inglés) integrado directamente en la aplicación Flutter. El chatbot utiliza **Groq API** como proveedor de LLM (sin costo en tier gratuito) y proporciona soporte en gestión médica y asistencia técnica para la plataforma.

---

## 🏗️ Arquitectura

### Capas Principales

```
┌─────────────────────────────────────────┐
│         ChatBotScreen (UI Layer)        │
│  - Gestión de estado local              │
│  - Renderizado de burbujas de chat      │
│  - Animación de parpadeo de avatar      │
└─────────────────┬───────────────────────┘
                  │
        ┌─────────▼──────────┐
        │  GeminiService     │
        │  (API Wrapper)     │
        │  - HTTP requests   │
        │  - Stream handling │
        │  - Error mgmt      │
        └─────────┬──────────┘
                  │
        ┌─────────▼──────────────────┐
        │   Groq API (llama-3.1)     │
        │   https://api.groq.com     │
        └────────────────────────────┘
```

### Flujo de Mensajes

1. **Usuario escribe** → `_messageController` actualiza estado
2. **Envía mensaje** → `_sendMessage()` agrega burbuja de usuario a `_messages`
3. **Streaming** → `GeminiService.streamResponse()` envía HTTP POST a Groq
4. **Respuesta** → Se parsea JSON en líneas SSE (Server-Sent Events)
5. **UI actualiza** → `setState()` redibuja burbuja del bot con texto progresivo
6. **Historial** → Se mantiene en `_history` de `GeminiService` (últimos 12 mensajes)

---

## 🔧 Componentes Clave

### 1. **ChatBotScreen** (`lib/views/chat_bot_screen.dart`)

**Responsabilidades:**
- Gestión completa del estado del chat (mensajes, generación, parpadeo)
- Renderizado de UI (AppBar, ListView de burbujas, composer)
- Manejo de entrada de usuario
- Navegación y scroll automático

**Estados:**
```dart
bool _isGenerating;      // True mientras la IA genera respuesta
bool _hasText;           // True si hay texto en el input
bool _isBlinking;        // True durante parpadeo del avatar
List<_ChatMessage> _messages; // Historial de chat
```

**Widgets internos:**
- `_ChatBubble`: Renderiza burbujas de usuario/bot con estilos diferenciados
- `_AnimatedTypingDots`: 3 puntos suspensivos con opacidad animada
- `_buildComposer()`: Caja de entrada con botón de envío

### 2. **GeminiService** (`lib/services/gemini_service.dart`)

**Responsabilidades:**
- Autenticación con Groq API
- Construcción de requests HTTP con system instructions
- Parsing de respuestas SSE en streaming
- Mantenimiento de historial de conversación
- Detección automática de idioma (español/inglés)
- Aplicación de regla ética (respuesta fija para preguntas de identidad)

**Método principal:**
```dart
Stream<String> streamResponse(String userMessage)
```
Retorna un stream que emite fragmentos de la respuesta conforme llegan del servidor.

**System Instructions:**
```
1. Detectar idioma del último mensaje del usuario
2. Responder en ese mismo idioma
3. Si pregunta por identidad/valores → respuesta ética fija
4. Contexto: experto en gestión médica + soporte técnico MediTime
```

**Historial:**
- Se mantiene hasta 12 intercambios recientes (`_maxHistoryMessages`)
- Reduce consumo de tokens y costo en Groq
- Se limpia automáticamente (`_trimHistory()`)

### 3. **_AnimatedTypingDots** (widget personalizado)

Reemplaza el `CircularProgressIndicator` original:
```dart
- 3 puntos circulares de 8x8 dp
- Alternan opacidad (1.0 → 0.25) en ciclos de ~260 ms
- Color gris oscuro (#6A7485)
- AnimatedOpacity para transiciones suaves
```

---

## 🚀 Configuración e Instalación

### Paso 1: Obtener API Key de Groq

1. Ir a: **https://console.groq.com/keys**
2. Crear una nueva API key (gratis, sin tarjeta de crédito)
3. Copiar la clave

### Paso 2: Registrar Assets

Los assets ya están en `pubspec.yaml`:
```yaml
assets:
  - assets/chatbot/midi_open.png
  - assets/chatbot/midi_blink.png
```

Verifica que existan en:
```
assets/
└── chatbot/
    ├── midi_open.png   (avatar normal)
    └── midi_blink.png  (avatar con parpadeo)
```

### Paso 3: Ejecutar la App

```bash
flutter pub get

# Con API key de Groq
flutter run --dart-define=GROQ_API_KEY="tu_api_key_aqui"

# Debug en Android/iOS específico
flutter run -d <device_id> --dart-define=GROQ_API_KEY="..."
```

### Paso 4: Acceder al Chatbot

1. Abre la app
2. Abre el **Drawer** (menú lateral) → opción "Asistente MediTime"
   O
3. Toca el botón de **ayuda** en la `HomeScreen`

---

## 📦 Dependencias

### Directas (agregadas para el chatbot):
```yaml
dependencies:
  http: ^1.1.0  # HTTP client para Groq API
```

(Nota: `provider` ya estaba en el proyecto para state management)

### Indirectas (usadas por http):
- `typed_data`
- `async`
- `http_parser`

### Removidas:
- ~~`google_generative_ai`~~ (usaba Gemini, cambió a Groq por cuota gratis)

---

## 🎨 Estilos y Diseño

### Colores

| Elemento | Color | Hex |
|----------|-------|-----|
| Degradado principal | Azul → Azul oscuro | #2296F3 → #316AA7 |
| Avatar (header) | Azul | Imagen PNG |
| Punto de estado | Verde | #59C156 |
| Burbuja usuario | Gradiente azul | #2296F3 → #316AA7 |
| Burbuja bot | Gris claro | #F0F0F2 |
| Texto usuario | Blanco | #FFFFFF |
| Texto bot | Gris oscuro | #222222 |
| Botón inactivo | Gris | #C0C5CF |

### Radios y Espacios

- **Composer input**: 30 dp (BorderRadius.circular)
- **Chat bubbles**: 28 dp superior + 9 dp cola inferior
- **Avatar**: 38 dp circular
- **Padding composer**: 16 dp lateral, 14 dp inferior
- **Padding burbujas**: 16 dp horizontal, 14 dp vertical

### Animaciones

| Elemento | Tipo | Duración |
|----------|------|----------|
| Parpadeo avatar | Fade + Timer aleatorio | 150 ms show, 2.2-6s wait |
| Puntos suspensivos | Opacity cycle | 260 ms por ciclo |
| Scroll | AnimateTo | 250 ms |

---

## 🔐 Seguridad y Privacidad

### Gestión de API Key

- **NO** hacer commit de la clave
- Usar `--dart-define` en tiempo de ejecución
- En CI/CD: usar secrets/environment variables
- La clave **NO** se almacena localmente

### Datos de Usuario

- **Mensajes**: se mantienen en RAM durante la sesión
- **Historial** en `GeminiService._history`: máx 12 intercambios (se borra al cerrar app)
- **Sin persistencia** a base de datos (diseño actual)
- **Sin analytics** de conversaciones

### System Instructions

Se envía en cada request (no se almacena):
```
- Experto en gestión médica
- Experto en soporte técnico MediTime
- Regla ética fija para identidad
```

---

## 🐛 Manejo de Errores

### Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| `Missing Groq API key` | No pasó `--dart-define=GROQ_API_KEY` | Ejecuta con flag de API key |
| `401 Unauthorized` | API key inválida o revocada | Genera nueva clave en console.groq.com |
| `429 Rate Limited` | Se alcanzó límite gratuito | Espera ~1.8 segundos o suscribe a plan pago |
| `The model is not found` | Modelo no disponible | Groq es agnóstico, prueba con `llama-3.1-8b-instant` |
| Timeout (>10s) | API lenta o red débil | Timeout está en `Duration(seconds: 5)` en stream |

### Logs y Debugging

Habilita logs en terminal:
```bash
flutter run -v  # Verbose mode
```

En el código, puedes agregar prints en:
- `GeminiService.streamResponse()` → línea 75+
- `_ChatBotScreenState._sendMessage()` → línea 85+

---

## 📊 Rendimiento y Optimizaciones

### Conversación Actual
- Últimos 12 mensajes en memoria (`_maxHistoryMessages`)
- Cada mensaje = ~50-500 bytes (varía por contenido)
- **Total**: ~6-12 KB típico

### Request/Response
- **Streaming**: Se renderiza conforme llega (UX fluida)
- **Sin buffering**: No se espera respuesta completa
- **Timeout**: 5 segundos por defecto

### Futuras Optimizaciones
- Persistencia en SQLite (historial entre sesiones)
- Compresión de historial antiguo
- Caché local de respuestas frecuentes
- Switch a Groq API en batch mode (no stream) para resp. cortas

---

## 🧪 Testing

### Casos de Prueba Manual

1. **Bilingüismo**
   - Escribe: "Hola"
   - Escribe: "Hello"
   - ✅ Responde en español e inglés respectivamente

2. **Regla Ética**
   - Escribe: "¿Quién eres?"
   - ✅ Responde con declaración ética fija

3. **Streaming**
   - Escribe pregunta larga
   - ✅ Burbujas se actualizan progresivamente
   - ✅ Puntos suspensivos animan mientras genera

4. **Parpadeo**
   - Espera ~3-5 segundos en la pantalla
   - ✅ Avatar parpadea ocasionalmente

5. **Historial**
   - Mantén conversación de 10+ intercambios
   - ✅ Contexto se preserva en respuestas

### Unit Tests (recomendado agregar)

```dart
// test/services/gemini_service_test.dart
void main() {
  test('Detects Spanish correctly', () async {
    final service = GeminiService(apiKey: 'test_key');
    final detected = service._requiresEthicalDeclaration('¿Quién eres?');
    expect(detected, true);
  });

  test('Streams response without blocking', () async {
    // Mock HTTP response
    // Verify stream emits chunks
  });
}
```

---

## 📝 Estructura de Archivos

```
lib/
├── views/
│   └── chat_bot_screen.dart       # UI principal del chatbot
├── services/
│   └── gemini_service.dart        # Wrapper de Groq API
├── main.dart                      # Route registrado: /chatbot
└── ...

assets/
└── chatbot/
    ├── midi_open.png              # Avatar estándar
    └── midi_blink.png             # Avatar parpadeando

pubspec.yaml                        # Dependencia http + assets
```

---

## 🎯 Próximos Pasos Sugeridos

1. **Persistencia**: Agregar SQLite para guardar historial entre sesiones
2. **Analytics**: Log anónimo de intenciones de usuario (para mejorar prompts)
3. **Caché**: Almacenar respuestas a preguntas frecuentes
4. **Webhooks**: Integración con backend (ej. agendar citas)
5. **Voz**: Speech-to-text + TTS para accesibilidad
6. **Modelos alternativos**: Support para otros LLMs (OpenAI, Claude, etc.)

---

## 📞 Troubleshooting

### "App se cuelga al enviar mensajes"
- Verifica conexión a internet
- Comprueba que GROQ_API_KEY sea válida
- Revisa logs: `flutter run -v`

### "Avatar no parpadea"
- Verifica que `assets/chatbot/*.png` existan
- Comprueba `pubspec.yaml` → `assets` section
- Ejecuta: `flutter pub get && flutter clean && flutter pub get`

### "Respuesta muy lenta"
- Groq puede estar saturada (peak hours)
- Prueba con requests más cortos
- Si es reproducible, contacta a soporte Groq

### "Mensajes no se desplazan al final"
- `_scrollToBottom()` usa `hasClients` check
- Verifica que ListView esté construido antes de scroll
- Agrega delay: `Future.delayed(Duration(ms: 50)) → scroll`

---

## 📄 Referencias

- **Groq API Docs**: https://console.groq.com/docs/chat-completions
- **Flutter Docs**: https://flutter.dev/docs
- **Dart HTTP**: https://pub.dev/packages/http
- **Material Design 3**: https://m3.material.io

---

## 👤 Autor / Contacto

Implementado como parte de **MediTime** — Sistema de Gestión de Salud.

**Última actualización**: 2026-05-13

---

**Nota**: Este README es técnico y asume conocimiento en Flutter/Dart. Para guía de usuario, ver `README.md` principal.
