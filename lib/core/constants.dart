// lib/core/constants.dart

/// Application-wide constants to avoid magic numbers and strings.
/// 
/// This file centralizes all constant values used throughout the application,
/// making them easier to maintain and modify.
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  // --- Time and Duration Constants ---
  static const int defaultSnoozeMinutes = 10;
  static const int defaultAlarmId = 0;
  static const String defaultTimeFormat = '00:00';
  static const String defaultDuration = '0';
  
  // --- Default Values ---
  static const String defaultMedicationName = 'N/A';
  static const String defaultPresentation = 'N/A';
  static const String defaultNotes = '';
  static const String defaultUserName = 'Usuario';
  static const String defaultProfileText = 'No especificado';
  
  // --- Collection Names ---
  static const String usersCollection = 'users';
  static const String medicamentosCollection = 'medicamentos';
  static const String userMedicamentosSubcollection = 'userMedicamentos';
  
  // --- Field Names ---
  static const String nameField = 'name';
  static const String emailField = 'email';
  static const String phoneField = 'phone';
  static const String dobField = 'dob';
  static const String bloodTypeField = 'bloodType';
  static const String allergiesField = 'allergies';
  static const String medicationsField = 'medications';
  static const String medicalHistoryField = 'medicalHistory';
  static const String profileImageField = 'profileImage';
  
  // Treatment fields
  static const String nombreMedicamentoField = 'nombreMedicamento';
  static const String presentacionField = 'presentacion';
  static const String duracionField = 'duracion';
  static const String horaPrimeraDosisField = 'horaPrimeraDosis';
  static const String intervaloDosisField = 'intervaloDosis';
  static const String prescriptionAlarmIdField = 'prescriptionAlarmId';
  static const String fechaInicioTratamientoField = 'fechaInicioTratamiento';
  static const String fechaFinTratamientoField = 'fechaFinTratamiento';
  static const String skippedDosesField = 'skippedDoses';
  static const String notasField = 'notas';
  static const String doseStatusField = 'doseStatus';
  
  // --- Error Messages ---
  static const String genericErrorMessage = 'Ha ocurrido un error inesperado';
  static const String networkErrorMessage = 'Error de conexión. Verifica tu internet';
  static const String authErrorMessage = 'Error de autenticación';
  static const String profileLoadErrorMessage = 'Error al cargar el perfil';
  static const String treatmentLoadErrorMessage = 'Error al cargar los tratamientos';
  static const String treatmentSaveErrorMessage = 'Error al guardar el tratamiento';
  static const String treatmentDeleteErrorMessage = 'Error al eliminar el tratamiento';
  static const String doseUpdateErrorMessage = 'Error al actualizar el estado de la dosis';
  static const String signOutErrorMessage = 'Error al cerrar sesión';
  static const String signInErrorMessage = 'Error al iniciar sesión';
  static const String createAccountErrorMessage = 'Error al crear la cuenta';
  static const String googleSignInErrorMessage = 'Error al iniciar sesión con Google';
  static const String googleSignInCancelledMessage = 'Inicio de sesión con Google cancelado';
  
  // --- Success Messages ---
  static const String profileSavedMessage = 'Perfil guardado correctamente';
  static const String treatmentSavedMessage = 'Tratamiento guardado correctamente';
  static const String treatmentDeletedMessage = 'Tratamiento eliminado correctamente';
  static const String changesSavedMessage = 'Cambios guardados';
  
  // --- UI Constants ---
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double defaultBorderRadius = 20.0;
  static const double smallBorderRadius = 8.0;
  static const double profileImageRadius = 55.0;
  static const double profileImageInnerRadius = 52.0;
  static const double drawerProfileImageRadius = 40.0;
  
  // --- Animation Durations ---
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration shortAnimationDuration = Duration(milliseconds: 150);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);
  
  // --- Validation Constants ---
  static const int minPasswordLength = 6;
  static const int maxNameLength = 50;
  static const int maxNotesLength = 500;
  
  // --- Asset Paths ---
  static const String defaultProfileImageAsset = 'assets/profile_picture.png';
  
  // --- Greeting Messages ---
  static const String morningGreeting = 'Buenos días';
  static const String afternoonGreeting = 'Buenas tardes';
  static const String eveningGreeting = 'Buenas noches';
  
  // --- Time Ranges ---
  static const int morningStartHour = 6;
  static const int afternoonStartHour = 12;
  static const int eveningStartHour = 18;
}