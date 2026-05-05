# Guía de Configuración de Cloudinary para MediTime

## Por qué Cloudinary

Firebase Storage ahora requiere plan de pago. **Cloudinary** ofrece:
- ✅ **Plan gratuito generoso**: 25 GB de almacenamiento/mes
- ✅ **Transformaciones de imagen**: compresión, redimensionamiento automático
- ✅ **API simple y confiable**
- ✅ **CDN global**: entrega rápida de imágenes
- ✅ **Sin tarjeta de crédito requerida** para plan gratuito (hasta límites razonables)

## Pasos para Configurar Cloudinary

### 1. Crear Cuenta en Cloudinary

1. Ve a [https://cloudinary.com/users/register/free](https://cloudinary.com/users/register/free)
2. Registrate con un email y contraseña
3. Verifica tu email
4. Selecciona "Developer" como caso de uso
5. Elige el nombre de tu cuenta (será tu `cloud_name`)

### 2. Obtener Credenciales

1. Después de registrarte, irás al **Dashboard**
2. En la sección **"Account Details"** verás:
   - **Cloud Name** (ej: `abc123def`)
   - **API Key** (ej: `123456789`)
   - **API Secret** (ej: `abcdef123456`)

### 3. Configurar Upload Preset (Recomendado - Sin Credenciales)

#### Opción A: Upload Sin Credenciales (MÁS SEGURA - Recomendada)

1. En el Dashboard de Cloudinary, ve a **Settings → Upload**
2. Baja hasta **"Upload presets"**
3. Haz clic en **"Add upload preset"**
4. Configura así:
   - **Folder**: `meditime/profiles`
   - **Unique filename**: `OFF` (para poder sobrescribir)
   - **Resource type**: `Image`
   - **Signing mode**: `Unsigned` ⭐ (IMPORTANTE)
   - Haz clic en **"Save"**

5. Copia el nombre del **Preset** (ej: `meditime_upload`)

#### Opción B: Upload Con Credenciales (Más Control)

Si prefieres usar API Key y Secret (requiere backend seguro):

1. En la app, solo necesitarás:
   - `cloudinaryCloudName`
   - `cloudinaryApiKey`

### 4. Configurar la App

#### En `lib/services/storage_service.dart`:

```dart
static const String cloudinaryCloudName = 'tu_cloud_name_aqui';
static const String cloudinaryApiKey = 'tu_api_key_aqui'; // Solo si usas credenciales
static const String cloudinaryUploadPreset = 'tu_preset_aqui'; // Si usas unsigned
```

**Ejemplo Real:**
```dart
static const String cloudinaryCloudName = 'meditime-cloud';
static const String cloudinaryUploadPreset = 'meditime_upload';
```

### 5. Obtener Dependencias

Run:
```bash
flutter pub get
```

Esto instalará el paquete `http` que usa el nuevo `StorageService`.

## Arquitectura de URLs en Cloudinary

Las imágenes se guardan así:

```
https://res.cloudinary.com/{CLOUD_NAME}/image/upload/meditime/profile_{USER_ID}.jpg
```

**Ejemplo:**
```
https://res.cloudinary.com/meditime-cloud/image/upload/meditime/profile_abc123.jpg
```

Puedes agregar transformaciones inline:
```
https://res.cloudinary.com/meditime-cloud/image/upload/w_300,h_300,c_fill/meditime/profile_abc123.jpg
```

## Flujo de Subida Actual

```
Usuario selecciona foto
        ↓
StorageService._compressImage() → 300x300px, calidad 70%
        ↓
HTTP POST a Cloudinary API
        ↓
Respuesta con URL de imagen
        ↓
Se guarda URL en Firestore → profileImage
        ↓
ProfileNotifier actualiza → muestra foto en UI
```

## Ventajas de la Configuración

✅ **Sin SDK de Firebase Storage** → menos dependencias, build más rápido
✅ **Compresión automática** → 300x300px, calidad controlada
✅ **Caché global** → imágenes servidas desde CDN más cercano
✅ **Almacenamiento ilimitado en plan gratuito** (hasta 25GB/mes)
✅ **URL pública** → la foto se muestra sin autenticación
✅ **Sobrescritura automática** → permite actualizar foto de perfil

## Solución de Problemas

### Error: "Upload preset not found"

- Verifica que el nombre del preset sea correcto en `storage_service.dart`
- Asegúrate que el preset esté configurado como "Unsigned"

### Error: "Invalid cloud name"

- Copia exactamente el Cloud Name del Dashboard de Cloudinary
- No incluyas espacios o caracteres especiales

### Imagen no aparece después de subir

- Confirma que `cloudinaryCloudName` es correcto
- Espera 1-2 segundos para que Cloudinary procese la imagen
- Abre la URL directamente en el navegador para verificar que existe

### Quiero usar API Key y Secret (más control)

Necesitarás:
1. Actualizar `storage_service.dart` para incluir firma de peticiones (HMAC)
2. Generar signature desde el backend (por seguridad)
3. Configurar credenciales privadas

## Plan Gratuito de Cloudinary

| Recurso | Límite Gratuito |
|---------|-----------------|
| Almacenamiento | 25 GB/mes |
| Ancho de banda | 25 GB/mes |
| Transformaciones | Ilimitado |
| Solicitudes API | 7500/mes |

**Para MediTime**: Con usuarios típicos (~10 imágenes de 50KB cada uno), tienes más que suficiente.

## Cambios en el Código

### Antes (Firebase Storage):
```dart
final FirebaseStorage _storage = FirebaseStorage.instance;
final downloadUrl = await storageRef.getDownloadURL();
```

### Ahora (Cloudinary):
```dart
// Petición HTTP a Cloudinary
var response = await request.send();
final downloadUrl = 'https://res.cloudinary.com/$cloudinaryCloudName/...';
```

## Próximos Pasos

1. ✅ Crea cuenta en Cloudinary
2. ✅ Obtén tus credenciales
3. ✅ Copia `Cloud Name` y `Upload Preset` en `storage_service.dart`
4. ✅ Ejecuta `flutter pub get`
5. ✅ Prueba subiendo una foto en la app

## Documentación Oficial

- **Cloudinary**: https://cloudinary.com/documentation
- **Upload API**: https://cloudinary.com/documentation/image_upload_api_reference
- **Transformaciones**: https://cloudinary.com/documentation/image_transformation_reference

---

**Estado**: ✅ Implementación Completa - Solo falta configurar tus credenciales
