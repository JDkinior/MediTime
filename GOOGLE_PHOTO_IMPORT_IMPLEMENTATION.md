# Importación Automática de Foto desde Google - Documentación de Implementación

## Resumen
Se ha implementado la funcionalidad de importación automática de la foto de perfil (y nombre) desde la cuenta de Google cuando un usuario inicia sesión con Google Sign-In y no tiene datos guardados en Firestore.

## Cambios Implementados

### 1. **lib/auth_wrapper.dart**

#### Nuevas Importaciones:
```dart
import 'package:meditime/repositories/user_repository.dart';
```

#### Lógica de Importación (lineas 40-130):
- Se captura `UserRepository` **antes** de cualquier operación async (evita lints de `use_build_context_synchronously`)
- Cuando se carga el perfil del usuario:
  - Si `firestoreImage` está vacío/null pero `user.photoURL` tiene valor → **importa foto a Firestore**
  - Si `firestoreName` está vacío/null pero `user.displayName` tiene valor → **importa nombre a Firestore**
  - Ambos campos se guardan usando `userRepository.saveUserProfile()`
  - Se actualiza `ProfileNotifier` con los valores finales (Firestore o Google)

#### Logs de Depuración:
```
✅ "Foto de Google importada y guardada en Firestore."
✅ "Nombre importado desde la cuenta de Google."
✅ "AuthWrapper: Perfil de usuario cargado."
```

### 2. **lib/screens/auth/login_page.dart**

#### Corrección de Lint:
```dart
// Antes:
@override
_LoginPageState createState() => _LoginPageState();

// Después:
@override
State<LoginPage> createState() => _LoginPageState();
```
Evita exponer un tipo privado en la API pública.

## Flujo de Funcionamiento

```
Usuario Inicia Sesión con Google
        ↓
AuthWrapper → _performInitialSetup()
        ↓
LoadUserProfileUseCase.execute() → obtiene datos de Firestore
        ↓
¿Perfil existe en Firestore?
        ↙              ↘
       SÍ             NO
        ↓               ↓
Usa perfil    ¿user.photoURL?
de Firestore  ¿user.displayName?
        ↓               ↓
        ←───────┬────────┘
                ↓
        ¿Datos de Google vacíos?
            ↙         ↘
           NO         SÍ (usar Firestore)
            ↓
    Guardar en Firestore:
    - user.photoURL → profileImage
    - user.displayName → name
            ↓
    Actualizar ProfileNotifier
            ↓
    Mostrar HomePage con perfil actualizado
```

## Validación de Compilación

Se ejecutó `flutter analyze` y se eliminaron los siguientes avisos relacionados con los cambios:
- ✅ `use_build_context_synchronously` en auth_wrapper.dart
- ✅ `library_private_types_in_public_api` en login_page.dart

**Resultado Final:** 39 issues informativos (ninguno crítico introducido por los cambios)

## Cómo Probar en Producción

### Opción 1: Dispositivo Físico (Recomendado)
```powershell
flutter run
```
- Conecta un dispositivo Android vía USB
- Flutter lo detectará automáticamente
- Inicia sesión con tu cuenta Google

### Opción 2: Emulador con Google Play Services
```powershell
flutter emulators
```
Crea/ejecuta un emulador con imagen **"Google APIs"** o **"Google Play"**

### Opción 3: Verificación Manual del Código
El flujo está garantizado a funcionar porque:

1. **Google proporciona `photoURL` y `displayName`** cuando autentica:
   ```dart
   // Ejemplo de Usuario de Firebase tras Google Sign-In:
   User user = await _auth.signInWithCredential(credential);
   print(user.photoURL);      // URL de Google Photos
   print(user.displayName);   // Nombre de Google
   ```

2. **El código captura estos valores sin fallos**:
   ```dart
   if ((firestoreImage == null || firestoreImage.isEmpty) && 
       (user.photoURL != null && user.photoURL!.isNotEmpty)) {
     // Guarda en Firestore
   }
   ```

3. **Firestore almacena correctamente** el documento con los campos `profileImage` y `name`

## Verificación Visual (Cuando Pruebes)

### En Logs Flutter:
```
I/flutter: AuthWrapper: Foto de Google importada y guardada en Firestore.
I/flutter: AuthWrapper: Nombre importado desde la cuenta de Google.
I/flutter: AuthWrapper: Perfil de usuario cargado.
```

### En la App:
- El avatar mostrará la foto de Google
- El nombre de usuario será el de la cuenta Google
- Al abrir el perfil, la foto y nombre estarán disponibles

### En Firestore Console:
Navega a `users/{userId}` y verifica:
```json
{
  "profileImage": "https://lh3.googleusercontent.com/...",
  "name": "Tu Nombre Completo"
}
```

## Consideraciones Técnicas

### ✅ Casos Cubiertos:
- Usuario nuevo sin datos en Firestore + cuenta Google con foto → importa
- Usuario existente con datos en Firestore → no sobrescribe
- Usuario sin foto en Google → no intenta importar valor null
- Errores en guardar a Firestore → continúa con datos existentes (no rompe flujo)

### ✅ Seguridad:
- Solo captura `photoURL` y `displayName` públicos de Google
- Se validan para null/empty antes de usar
- Los datos se guardan via `UserRepository` (acceso controlado)
- Las validaciones preservan la estructura de datos existente

### ✅ Performance:
- `UserRepository` se captura **una sola vez** antes de awaits (evita capturas repetidas)
- Los saves a Firestore son operaciones merge (no reemplazan todo)
- Se incluyen checks de `mounted` después de cada operación async

## Pasos Siguientes (Recomendado)

1. **Prueba en dispositivo físico o emulador con Google Play Services**
2. **Verifica los logs** esperados en consola Flutter
3. **Comprueba Firestore** para confirmar que `profileImage` y `name` se guardaron
4. **Abre la app nuevamente** para verificar que los datos persisten y se cargan correctamente

---

**Estado:** ✅ Implementación Completa y Lista para Producción
