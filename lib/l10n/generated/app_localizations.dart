import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// Nombre de la aplicación
  ///
  /// In es, this message translates to:
  /// **'MediTime'**
  String get appTitle;

  /// No description provided for @commonAccept.
  ///
  /// In es, this message translates to:
  /// **'Aceptar'**
  String get commonAccept;

  /// No description provided for @commonCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get commonSave;

  /// No description provided for @commonClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get commonClose;

  /// No description provided for @commonDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get commonEdit;

  /// No description provided for @commonConfirm.
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get commonConfirm;

  /// No description provided for @commonError.
  ///
  /// In es, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonSuccess.
  ///
  /// In es, this message translates to:
  /// **'Éxito'**
  String get commonSuccess;

  /// No description provided for @commonLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando...'**
  String get commonLoading;

  /// No description provided for @commonRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get commonRetry;

  /// No description provided for @navHome.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get navHome;

  /// No description provided for @navCalendar.
  ///
  /// In es, this message translates to:
  /// **'Calendario'**
  String get navCalendar;

  /// No description provided for @navMedications.
  ///
  /// In es, this message translates to:
  /// **'Medicamentos'**
  String get navMedications;

  /// No description provided for @navPrescription.
  ///
  /// In es, this message translates to:
  /// **'Receta'**
  String get navPrescription;

  /// No description provided for @navProgress.
  ///
  /// In es, this message translates to:
  /// **'Progreso'**
  String get navProgress;

  /// No description provided for @navProfile.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get navProfile;

  /// No description provided for @navChatBot.
  ///
  /// In es, this message translates to:
  /// **'Midi Chat'**
  String get navChatBot;

  /// No description provided for @appBarProgress.
  ///
  /// In es, this message translates to:
  /// **'Mi Progreso'**
  String get appBarProgress;

  /// No description provided for @appBarCalendar.
  ///
  /// In es, this message translates to:
  /// **'Calendario'**
  String get appBarCalendar;

  /// No description provided for @appBarMedications.
  ///
  /// In es, this message translates to:
  /// **'Medicamentos'**
  String get appBarMedications;

  /// No description provided for @appBarProfile.
  ///
  /// In es, this message translates to:
  /// **'Mi Perfil'**
  String get appBarProfile;

  /// No description provided for @appBarAdherenceReport.
  ///
  /// In es, this message translates to:
  /// **'Reporte de Adherencia'**
  String get appBarAdherenceReport;

  /// No description provided for @appBarHelp.
  ///
  /// In es, this message translates to:
  /// **'Ayuda y Soporte'**
  String get appBarHelp;

  /// No description provided for @drawerCaregiverMode.
  ///
  /// In es, this message translates to:
  /// **'Modo Cuidador'**
  String get drawerCaregiverMode;

  /// No description provided for @drawerSectionMain.
  ///
  /// In es, this message translates to:
  /// **'PRINCIPAL'**
  String get drawerSectionMain;

  /// No description provided for @drawerProfile.
  ///
  /// In es, this message translates to:
  /// **'Mi Perfil'**
  String get drawerProfile;

  /// No description provided for @drawerProfileSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Ver y editar tu información'**
  String get drawerProfileSubtitle;

  /// No description provided for @drawerAdherenceReport.
  ///
  /// In es, this message translates to:
  /// **'Reporte de Adherencia'**
  String get drawerAdherenceReport;

  /// No description provided for @drawerAdherenceReportSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas y reportes'**
  String get drawerAdherenceReportSubtitle;

  /// No description provided for @drawerOptions.
  ///
  /// In es, this message translates to:
  /// **'Opciones'**
  String get drawerOptions;

  /// No description provided for @drawerOptionsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes de la aplicación'**
  String get drawerOptionsSubtitle;

  /// No description provided for @drawerSectionHelp.
  ///
  /// In es, this message translates to:
  /// **'AYUDA'**
  String get drawerSectionHelp;

  /// No description provided for @drawerHelp.
  ///
  /// In es, this message translates to:
  /// **'Ayuda'**
  String get drawerHelp;

  /// No description provided for @drawerHelpSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Centro de ayuda y soporte'**
  String get drawerHelpSubtitle;

  /// No description provided for @drawerTutorial.
  ///
  /// In es, this message translates to:
  /// **'Tutorial'**
  String get drawerTutorial;

  /// No description provided for @drawerTutorialSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Guías y consejos de uso'**
  String get drawerTutorialSubtitle;

  /// No description provided for @drawerChatbot.
  ///
  /// In es, this message translates to:
  /// **'Chatbot MediTime'**
  String get drawerChatbot;

  /// No description provided for @drawerChatbotSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Asistente inteligente'**
  String get drawerChatbotSubtitle;

  /// No description provided for @drawerSectionManage.
  ///
  /// In es, this message translates to:
  /// **'GESTIÓN'**
  String get drawerSectionManage;

  /// No description provided for @drawerManagePatients.
  ///
  /// In es, this message translates to:
  /// **'Gestionar Pacientes'**
  String get drawerManagePatients;

  /// No description provided for @drawerManagePatientsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Agregar, editar o eliminar'**
  String get drawerManagePatientsSubtitle;

  /// No description provided for @drawerCaregiverSettings.
  ///
  /// In es, this message translates to:
  /// **'Configuración Cuidador'**
  String get drawerCaregiverSettings;

  /// No description provided for @drawerCaregiverSettingsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Preferencias del modo cuidador'**
  String get drawerCaregiverSettingsSubtitle;

  /// No description provided for @drawerLogout.
  ///
  /// In es, this message translates to:
  /// **'Salir'**
  String get drawerLogout;

  /// No description provided for @drawerLogoutSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get drawerLogoutSubtitle;

  /// No description provided for @optionsTitle.
  ///
  /// In es, this message translates to:
  /// **'Opciones'**
  String get optionsTitle;

  /// No description provided for @optionsAccessibility.
  ///
  /// In es, this message translates to:
  /// **'Accesibilidad'**
  String get optionsAccessibility;

  /// No description provided for @optionsAccessibilitySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Oculta opciones secundarias y se enfoca solo en lo más importante.'**
  String get optionsAccessibilitySubtitle;

  /// No description provided for @optionsAppearance.
  ///
  /// In es, this message translates to:
  /// **'Diseño y Apariencia'**
  String get optionsAppearance;

  /// No description provided for @optionsAppearanceSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Personaliza la apariencia de la app a tu gusto.'**
  String get optionsAppearanceSubtitle;

  /// No description provided for @optionsNotifications.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones y Alarmas'**
  String get optionsNotifications;

  /// No description provided for @optionsNotificationsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Configura cómo quieres recibir tus recordatorios.'**
  String get optionsNotificationsSubtitle;

  /// No description provided for @optionsPrivacy.
  ///
  /// In es, this message translates to:
  /// **'Datos y Privacidad'**
  String get optionsPrivacy;

  /// No description provided for @optionsPrivacySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Gestiona tu historial médico y de chats.'**
  String get optionsPrivacySubtitle;

  /// No description provided for @optionsCaregiver.
  ///
  /// In es, this message translates to:
  /// **'Modo Cuidador'**
  String get optionsCaregiver;

  /// No description provided for @optionsCaregiverSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Configura la gestión multi-perfil para familiares o sector clínico.'**
  String get optionsCaregiverSubtitle;

  /// No description provided for @optionsAnimals.
  ///
  /// In es, this message translates to:
  /// **'Modo Animales (Veterinaria)'**
  String get optionsAnimals;

  /// No description provided for @optionsAnimalsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Adapta la aplicación para veterinarias y mascotas (individual o múltiple).'**
  String get optionsAnimalsSubtitle;

  /// No description provided for @drawerAnimalsMode.
  ///
  /// In es, this message translates to:
  /// **'Modo Animales'**
  String get drawerAnimalsMode;

  /// No description provided for @drawerManageAnimals.
  ///
  /// In es, this message translates to:
  /// **'Gestionar Mascotas / Animales'**
  String get drawerManageAnimals;

  /// No description provided for @drawerManageAnimalsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Agregar, editar o dar de alta'**
  String get drawerManageAnimalsSubtitle;

  /// No description provided for @drawerAnimalsSettings.
  ///
  /// In es, this message translates to:
  /// **'Configuración Modo Animales'**
  String get drawerAnimalsSettings;

  /// No description provided for @drawerAnimalsSettingsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Preferencias del modo animales y veterinaria'**
  String get drawerAnimalsSettingsSubtitle;

  /// No description provided for @optionsLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get optionsLanguage;

  /// No description provided for @optionsLanguageSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Selecciona el idioma de la aplicación.'**
  String get optionsLanguageSubtitle;

  /// No description provided for @languageTitle.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get languageTitle;

  /// No description provided for @languageSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Selecciona tu idioma preferido para la interfaz.'**
  String get languageSubtitle;

  /// No description provided for @languageSystem.
  ///
  /// In es, this message translates to:
  /// **'Automático (Sistema)'**
  String get languageSystem;

  /// No description provided for @languageSystemDesc.
  ///
  /// In es, this message translates to:
  /// **'Seguir la configuración del dispositivo'**
  String get languageSystemDesc;

  /// No description provided for @languageSpanish.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @languageSpanishDesc.
  ///
  /// In es, this message translates to:
  /// **'Español (predeterminado)'**
  String get languageSpanishDesc;

  /// No description provided for @languageEnglish.
  ///
  /// In es, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageEnglishDesc.
  ///
  /// In es, this message translates to:
  /// **'Inglés'**
  String get languageEnglishDesc;

  /// No description provided for @languageChangedSnackbar.
  ///
  /// In es, this message translates to:
  /// **'Idioma actualizado correctamente.'**
  String get languageChangedSnackbar;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In es, this message translates to:
  /// **'¡Buenos días!'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In es, this message translates to:
  /// **'¡Buenas tardes!'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In es, this message translates to:
  /// **'¡Buenas noches!'**
  String get homeGreetingEvening;

  /// No description provided for @homeNextDose.
  ///
  /// In es, this message translates to:
  /// **'Próxima toma'**
  String get homeNextDose;

  /// No description provided for @homeTodayDoses.
  ///
  /// In es, this message translates to:
  /// **'Tomas de hoy'**
  String get homeTodayDoses;

  /// No description provided for @homeCompleted.
  ///
  /// In es, this message translates to:
  /// **'Completadas'**
  String get homeCompleted;

  /// No description provided for @homePending.
  ///
  /// In es, this message translates to:
  /// **'Pendientes'**
  String get homePending;

  /// No description provided for @homeNoPendingDoses.
  ///
  /// In es, this message translates to:
  /// **'No tienes tomas pendientes por ahora.'**
  String get homeNoPendingDoses;

  /// No description provided for @homeAddTreatment.
  ///
  /// In es, this message translates to:
  /// **'Agregar Tratamiento'**
  String get homeAddTreatment;

  /// No description provided for @helloUser.
  ///
  /// In es, this message translates to:
  /// **'Hola, {name}'**
  String helloUser(String name);

  /// No description provided for @planForToday.
  ///
  /// In es, this message translates to:
  /// **'Aquí está tu plan para hoy'**
  String get planForToday;

  /// No description provided for @planForDay.
  ///
  /// In es, this message translates to:
  /// **'Aquí está tu plan para este día'**
  String get planForDay;

  /// No description provided for @summaryToday.
  ///
  /// In es, this message translates to:
  /// **'Resumen de hoy'**
  String get summaryToday;

  /// No description provided for @summaryDay.
  ///
  /// In es, this message translates to:
  /// **'Resumen del día'**
  String get summaryDay;

  /// No description provided for @pendingUppercase.
  ///
  /// In es, this message translates to:
  /// **'PENDIENTES'**
  String get pendingUppercase;

  /// No description provided for @takenUppercase.
  ///
  /// In es, this message translates to:
  /// **'TOMADAS'**
  String get takenUppercase;

  /// No description provided for @adherenceUppercase.
  ///
  /// In es, this message translates to:
  /// **'ADHERENCIA'**
  String get adherenceUppercase;

  /// No description provided for @upcomingDoses.
  ///
  /// In es, this message translates to:
  /// **'Próximas dosis'**
  String get upcomingDoses;

  /// No description provided for @dosesOfTheDay.
  ///
  /// In es, this message translates to:
  /// **'Dosis del día'**
  String get dosesOfTheDay;

  /// No description provided for @noDosesToday.
  ///
  /// In es, this message translates to:
  /// **'No tienes dosis programadas para hoy.'**
  String get noDosesToday;

  /// No description provided for @noDosesDay.
  ///
  /// In es, this message translates to:
  /// **'No tienes dosis programadas para este día.'**
  String get noDosesDay;

  /// No description provided for @everyHours.
  ///
  /// In es, this message translates to:
  /// **'Cada {hours} horas'**
  String everyHours(int hours);

  /// No description provided for @everyHourSingle.
  ///
  /// In es, this message translates to:
  /// **'Cada hora'**
  String get everyHourSingle;

  /// No description provided for @actionTake.
  ///
  /// In es, this message translates to:
  /// **'Tomar'**
  String get actionTake;

  /// No description provided for @actionSkip.
  ///
  /// In es, this message translates to:
  /// **'Omitir'**
  String get actionSkip;

  /// No description provided for @actionSnooze.
  ///
  /// In es, this message translates to:
  /// **'Aplazar'**
  String get actionSnooze;

  /// No description provided for @doseTakenSuccess.
  ///
  /// In es, this message translates to:
  /// **'Toma registrada exitosamente'**
  String get doseTakenSuccess;

  /// No description provided for @doseSkippedSuccess.
  ///
  /// In es, this message translates to:
  /// **'Toma omitida'**
  String get doseSkippedSuccess;

  /// Mensaje cuando se aplaza una toma
  ///
  /// In es, this message translates to:
  /// **'Toma aplazada por {minutes} minutos'**
  String doseSnoozedSuccess(int minutes);

  /// No description provided for @doseStatusPending.
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get doseStatusPending;

  /// No description provided for @doseStatusNotified.
  ///
  /// In es, this message translates to:
  /// **'Notificada'**
  String get doseStatusNotified;

  /// No description provided for @doseStatusTaken.
  ///
  /// In es, this message translates to:
  /// **'Tomada'**
  String get doseStatusTaken;

  /// No description provided for @doseStatusSkipped.
  ///
  /// In es, this message translates to:
  /// **'Omitida'**
  String get doseStatusSkipped;

  /// No description provided for @doseStatusSnoozed.
  ///
  /// In es, this message translates to:
  /// **'Aplazada'**
  String get doseStatusSnoozed;

  /// No description provided for @doseStatusScheduled.
  ///
  /// In es, this message translates to:
  /// **'Programada'**
  String get doseStatusScheduled;

  /// No description provided for @presentationComprimidos.
  ///
  /// In es, this message translates to:
  /// **'Comprimidos'**
  String get presentationComprimidos;

  /// No description provided for @presentationGrageas.
  ///
  /// In es, this message translates to:
  /// **'Grageas'**
  String get presentationGrageas;

  /// No description provided for @presentationCapsulas.
  ///
  /// In es, this message translates to:
  /// **'Cápsulas'**
  String get presentationCapsulas;

  /// No description provided for @presentationSobres.
  ///
  /// In es, this message translates to:
  /// **'Sobres'**
  String get presentationSobres;

  /// No description provided for @presentationJarabes.
  ///
  /// In es, this message translates to:
  /// **'Jarabes'**
  String get presentationJarabes;

  /// No description provided for @presentationGotas.
  ///
  /// In es, this message translates to:
  /// **'Gotas'**
  String get presentationGotas;

  /// No description provided for @presentationSuspensiones.
  ///
  /// In es, this message translates to:
  /// **'Suspensiones'**
  String get presentationSuspensiones;

  /// No description provided for @presentationEmulsiones.
  ///
  /// In es, this message translates to:
  /// **'Emulsiones'**
  String get presentationEmulsiones;

  /// No description provided for @daySummary.
  ///
  /// In es, this message translates to:
  /// **'Resumen del día'**
  String get daySummary;

  /// No description provided for @dosesCompletedSummary.
  ///
  /// In es, this message translates to:
  /// **'{taken} de {total} dosis completadas'**
  String dosesCompletedSummary(int taken, int total);

  /// No description provided for @medicationsOfTheDay.
  ///
  /// In es, this message translates to:
  /// **'Medicamentos del día'**
  String get medicationsOfTheDay;

  /// No description provided for @treatmentDetailTitle.
  ///
  /// In es, this message translates to:
  /// **'Detalle del Tratamiento'**
  String get treatmentDetailTitle;

  /// No description provided for @treatmentMedicineName.
  ///
  /// In es, this message translates to:
  /// **'Medicamento'**
  String get treatmentMedicineName;

  /// No description provided for @treatmentDose.
  ///
  /// In es, this message translates to:
  /// **'Dosis'**
  String get treatmentDose;

  /// No description provided for @treatmentFrequency.
  ///
  /// In es, this message translates to:
  /// **'Frecuencia'**
  String get treatmentFrequency;

  /// No description provided for @treatmentInstructions.
  ///
  /// In es, this message translates to:
  /// **'Instrucciones'**
  String get treatmentInstructions;

  /// No description provided for @treatmentActive.
  ///
  /// In es, this message translates to:
  /// **'Activo'**
  String get treatmentActive;

  /// No description provided for @treatmentFinished.
  ///
  /// In es, this message translates to:
  /// **'Finalizado'**
  String get treatmentFinished;

  /// No description provided for @calendarTitle.
  ///
  /// In es, this message translates to:
  /// **'Calendario'**
  String get calendarTitle;

  /// No description provided for @calendarToday.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get calendarToday;

  /// No description provided for @calendarNoEvents.
  ///
  /// In es, this message translates to:
  /// **'No hay dosis programadas para este día.'**
  String get calendarNoEvents;

  /// No description provided for @intervalWeek.
  ///
  /// In es, this message translates to:
  /// **'Semana'**
  String get intervalWeek;

  /// No description provided for @intervalMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes'**
  String get intervalMonth;

  /// No description provided for @intervalYear.
  ///
  /// In es, this message translates to:
  /// **'Año'**
  String get intervalYear;

  /// No description provided for @intervalAll.
  ///
  /// In es, this message translates to:
  /// **'Todo'**
  String get intervalAll;

  /// No description provided for @overallPerformance.
  ///
  /// In es, this message translates to:
  /// **'Tu desempeño general'**
  String get overallPerformance;

  /// No description provided for @adherence.
  ///
  /// In es, this message translates to:
  /// **'Adherencia'**
  String get adherence;

  /// No description provided for @taken.
  ///
  /// In es, this message translates to:
  /// **'Tomadas'**
  String get taken;

  /// No description provided for @skipped.
  ///
  /// In es, this message translates to:
  /// **'Omitidas'**
  String get skipped;

  /// No description provided for @activeStreak.
  ///
  /// In es, this message translates to:
  /// **'Racha activa'**
  String get activeStreak;

  /// No description provided for @streakDays.
  ///
  /// In es, this message translates to:
  /// **'{count} {count, plural, =1{día} other{días}}'**
  String streakDays(int count);

  /// No description provided for @insightNoDataTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin datos'**
  String get insightNoDataTitle;

  /// No description provided for @insightNoDataText.
  ///
  /// In es, this message translates to:
  /// **'No hay dosis programadas. Agrega medicamentos para ver tu progreso.'**
  String get insightNoDataText;

  /// No description provided for @insightGoodTitle.
  ///
  /// In es, this message translates to:
  /// **'¡Buen ritmo!'**
  String get insightGoodTitle;

  /// No description provided for @insightGoodText.
  ///
  /// In es, this message translates to:
  /// **'Pequeños hábitos, grandes resultados. ¡Sigue así!'**
  String get insightGoodText;

  /// No description provided for @insightAttentionTitle.
  ///
  /// In es, this message translates to:
  /// **'Atención'**
  String get insightAttentionTitle;

  /// No description provided for @insightAttentionText.
  ///
  /// In es, this message translates to:
  /// **'Buen ritmo, pero has tenido algunas omisiones.'**
  String get insightAttentionText;

  /// No description provided for @insightAlertTitle.
  ///
  /// In es, this message translates to:
  /// **'¡Alerta!'**
  String get insightAlertTitle;

  /// No description provided for @insightAlertText.
  ///
  /// In es, this message translates to:
  /// **'Tu nivel de adherencia actual es bajo. Revisa tus alarmas.'**
  String get insightAlertText;

  /// No description provided for @weekSummary.
  ///
  /// In es, this message translates to:
  /// **'Resumen de la semana'**
  String get weekSummary;

  /// No description provided for @monthSummary.
  ///
  /// In es, this message translates to:
  /// **'Resumen del mes'**
  String get monthSummary;

  /// No description provided for @yearSummary.
  ///
  /// In es, this message translates to:
  /// **'Resumen del año'**
  String get yearSummary;

  /// No description provided for @cumulativeSummary.
  ///
  /// In es, this message translates to:
  /// **'Resumen acumulado'**
  String get cumulativeSummary;

  /// No description provided for @dosesInPeriod.
  ///
  /// In es, this message translates to:
  /// **'{count} dosis en periodo'**
  String dosesInPeriod(int count);

  /// No description provided for @mostRecent.
  ///
  /// In es, this message translates to:
  /// **'Más recientes'**
  String get mostRecent;

  /// No description provided for @oldestFirst.
  ///
  /// In es, this message translates to:
  /// **'Más antiguos'**
  String get oldestFirst;

  /// No description provided for @seeMore.
  ///
  /// In es, this message translates to:
  /// **'Ver más ({count} dosis más)'**
  String seeMore(int count);

  /// No description provided for @seeLess.
  ///
  /// In es, this message translates to:
  /// **'Ver menos'**
  String get seeLess;

  /// No description provided for @complianceWeekly.
  ///
  /// In es, this message translates to:
  /// **'Cumplimiento de la semana'**
  String get complianceWeekly;

  /// No description provided for @complianceMonthly.
  ///
  /// In es, this message translates to:
  /// **'Cumplimiento del mes'**
  String get complianceMonthly;

  /// No description provided for @complianceYearly.
  ///
  /// In es, this message translates to:
  /// **'Cumplimiento del año'**
  String get complianceYearly;

  /// No description provided for @complianceHistorical.
  ///
  /// In es, this message translates to:
  /// **'Cumplimiento histórico'**
  String get complianceHistorical;

  /// No description provided for @complianceWeeklySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Porcentaje de tomas por día'**
  String get complianceWeeklySubtitle;

  /// No description provided for @complianceMonthlySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Porcentaje de tomas por bloques de 5 días'**
  String get complianceMonthlySubtitle;

  /// No description provided for @complianceYearlySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Porcentaje de tomas por mes'**
  String get complianceYearlySubtitle;

  /// No description provided for @complianceHistoricalSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Porcentaje de tomas en los últimos 6 meses'**
  String get complianceHistoricalSubtitle;

  /// No description provided for @complianceChartTitle.
  ///
  /// In es, this message translates to:
  /// **'Gráfico de cumplimiento'**
  String get complianceChartTitle;

  /// No description provided for @progressByPatient.
  ///
  /// In es, this message translates to:
  /// **'Progreso por paciente'**
  String get progressByPatient;

  /// No description provided for @chatBotGreeting.
  ///
  /// In es, this message translates to:
  /// **'¡Hola! Soy Midi, tu asistente de salud en MediTime.'**
  String get chatBotGreeting;

  /// No description provided for @chatBotPlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Escribe un mensaje o haz una pregunta médica...'**
  String get chatBotPlaceholder;

  /// No description provided for @chatBotListening.
  ///
  /// In es, this message translates to:
  /// **'Escuchando...'**
  String get chatBotListening;

  /// No description provided for @chatBotClearHistory.
  ///
  /// In es, this message translates to:
  /// **'Borrar conversación'**
  String get chatBotClearHistory;

  /// No description provided for @loginSlogan.
  ///
  /// In es, this message translates to:
  /// **'Controla tus medicamentos\nMejora tu salud'**
  String get loginSlogan;

  /// No description provided for @loginSignIn.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get loginSignIn;

  /// No description provided for @loginRegister.
  ///
  /// In es, this message translates to:
  /// **'Registrarme'**
  String get loginRegister;

  /// No description provided for @loginEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo Electrónico'**
  String get loginEmailLabel;

  /// No description provided for @loginEmailHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe tu correo electrónico'**
  String get loginEmailHint;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get loginPasswordLabel;

  /// No description provided for @loginPasswordHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe tu contraseña'**
  String get loginPasswordHint;

  /// No description provided for @loginButton.
  ///
  /// In es, this message translates to:
  /// **'Iniciar Sesión'**
  String get loginButton;

  /// No description provided for @loginOr.
  ///
  /// In es, this message translates to:
  /// **'o'**
  String get loginOr;

  /// No description provided for @loginWithGoogle.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get loginWithGoogle;

  /// No description provided for @loginNoAccount.
  ///
  /// In es, this message translates to:
  /// **'¿No tienes cuenta? Regístrate aquí'**
  String get loginNoAccount;

  /// No description provided for @loginErrorEmptyEmail.
  ///
  /// In es, this message translates to:
  /// **'Por favor ingresa tu correo'**
  String get loginErrorEmptyEmail;

  /// No description provided for @loginErrorEmptyPassword.
  ///
  /// In es, this message translates to:
  /// **'Por favor ingresa tu contraseña'**
  String get loginErrorEmptyPassword;

  /// No description provided for @loginErrorGeneral.
  ///
  /// In es, this message translates to:
  /// **'Error al iniciar sesión'**
  String get loginErrorGeneral;

  /// No description provided for @loginErrorUserNotFound.
  ///
  /// In es, this message translates to:
  /// **'Usuario no encontrado'**
  String get loginErrorUserNotFound;

  /// No description provided for @loginErrorWrongPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña incorrecta'**
  String get loginErrorWrongPassword;

  /// No description provided for @loginErrorInvalidEmail.
  ///
  /// In es, this message translates to:
  /// **'Formato de correo inválido'**
  String get loginErrorInvalidEmail;

  /// No description provided for @loginErrorGoogle.
  ///
  /// In es, this message translates to:
  /// **'Error al iniciar sesión con Google. Inténtalo de nuevo.'**
  String get loginErrorGoogle;

  /// No description provided for @registerTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Comienza a gestionar tus medicamentos'**
  String get registerSubtitle;

  /// No description provided for @registerPasswordHint.
  ///
  /// In es, this message translates to:
  /// **'Crea tu contraseña'**
  String get registerPasswordHint;

  /// No description provided for @registerButton.
  ///
  /// In es, this message translates to:
  /// **'Registrarme'**
  String get registerButton;

  /// No description provided for @registerAlreadyHaveAccount.
  ///
  /// In es, this message translates to:
  /// **'¿Ya tienes cuenta? Inicia sesión aquí'**
  String get registerAlreadyHaveAccount;

  /// No description provided for @registerErrorInvalidEmail.
  ///
  /// In es, this message translates to:
  /// **'Por favor ingresa un correo válido'**
  String get registerErrorInvalidEmail;

  /// No description provided for @registerErrorShortPassword.
  ///
  /// In es, this message translates to:
  /// **'La contraseña debe tener al menos 6 caracteres'**
  String get registerErrorShortPassword;

  /// No description provided for @registerErrorFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo crear la cuenta'**
  String get registerErrorFailed;

  /// No description provided for @registerErrorEmailInUse.
  ///
  /// In es, this message translates to:
  /// **'El correo ya está en uso'**
  String get registerErrorEmailInUse;

  /// No description provided for @registerErrorWeakPassword.
  ///
  /// In es, this message translates to:
  /// **'La contraseña es demasiado débil'**
  String get registerErrorWeakPassword;

  /// No description provided for @registerErrorGoogle.
  ///
  /// In es, this message translates to:
  /// **'Error al registrarse con Google. Inténtalo de nuevo.'**
  String get registerErrorGoogle;

  /// No description provided for @doseDetailDoseTime.
  ///
  /// In es, this message translates to:
  /// **'Hora de esta toma'**
  String get doseDetailDoseTime;

  /// No description provided for @doseDetailTreatmentFinished.
  ///
  /// In es, this message translates to:
  /// **'Tratamiento Finalizado'**
  String get doseDetailTreatmentFinished;

  /// No description provided for @doseDetailNoMoreDoses.
  ///
  /// In es, this message translates to:
  /// **'No hay más dosis programadas.'**
  String get doseDetailNoMoreDoses;

  /// No description provided for @doseDetailNextDosePrompt.
  ///
  /// In es, this message translates to:
  /// **'Esta es la próxima dosis'**
  String get doseDetailNextDosePrompt;

  /// No description provided for @doseDetailNextAlarm.
  ///
  /// In es, this message translates to:
  /// **'Próxima Alarma:'**
  String get doseDetailNextAlarm;

  /// No description provided for @doseDetailTimeNow.
  ///
  /// In es, this message translates to:
  /// **'Es momento de tomar la dosis'**
  String get doseDetailTimeNow;

  /// No description provided for @doseDetailInSeconds.
  ///
  /// In es, this message translates to:
  /// **'En {seconds} segundos'**
  String doseDetailInSeconds(int seconds);

  /// No description provided for @doseDetailInDaysHours.
  ///
  /// In es, this message translates to:
  /// **'En {days} días y {hours} horas'**
  String doseDetailInDaysHours(int days, int hours);

  /// No description provided for @doseDetailInHoursMinutes.
  ///
  /// In es, this message translates to:
  /// **'En {hours} horas y {minutes} minutos'**
  String doseDetailInHoursMinutes(int hours, int minutes);

  /// No description provided for @doseDetailInMinutes.
  ///
  /// In es, this message translates to:
  /// **'En {minutes} minutos'**
  String doseDetailInMinutes(int minutes);

  /// No description provided for @doseDetailUpdateError.
  ///
  /// In es, this message translates to:
  /// **'Error al actualizar la dosis'**
  String get doseDetailUpdateError;

  /// No description provided for @treatmentSummaryMedicine.
  ///
  /// In es, this message translates to:
  /// **'Medicamento'**
  String get treatmentSummaryMedicine;

  /// No description provided for @treatmentSummaryPresentation.
  ///
  /// In es, this message translates to:
  /// **'Presentación: {presentation}'**
  String treatmentSummaryPresentation(String presentation);

  /// No description provided for @treatmentSummarySchedules.
  ///
  /// In es, this message translates to:
  /// **'Horarios'**
  String get treatmentSummarySchedules;

  /// No description provided for @treatmentSummaryDuration.
  ///
  /// In es, this message translates to:
  /// **'Duración'**
  String get treatmentSummaryDuration;

  /// No description provided for @treatmentSummaryNotDefined.
  ///
  /// In es, this message translates to:
  /// **'• No definido'**
  String get treatmentSummaryNotDefined;

  /// No description provided for @treatmentSummaryDaysInParentheses.
  ///
  /// In es, this message translates to:
  /// **'({days} días)'**
  String treatmentSummaryDaysInParentheses(int days);

  /// No description provided for @treatmentSummaryEveryHours.
  ///
  /// In es, this message translates to:
  /// **'Cada {hours} horas'**
  String treatmentSummaryEveryHours(int hours);

  /// No description provided for @treatmentSummaryAutoGenerated.
  ///
  /// In es, this message translates to:
  /// **'• Dosis generadas automáticamente'**
  String get treatmentSummaryAutoGenerated;

  /// No description provided for @treatmentSummaryTotalDoses.
  ///
  /// In es, this message translates to:
  /// **'• Total {total} dosis'**
  String treatmentSummaryTotalDoses(String total);

  /// No description provided for @treatmentSummaryUntil.
  ///
  /// In es, this message translates to:
  /// **'• Hasta {date}'**
  String treatmentSummaryUntil(String date);

  /// No description provided for @treatmentSummaryStockTitle.
  ///
  /// In es, this message translates to:
  /// **'Inventario y Stock'**
  String get treatmentSummaryStockTitle;

  /// No description provided for @treatmentSummaryStockAvailable.
  ///
  /// In es, this message translates to:
  /// **'Disponible: {current} de {total}'**
  String treatmentSummaryStockAvailable(int current, int total);

  /// No description provided for @treatmentSummaryDosePerIntake.
  ///
  /// In es, this message translates to:
  /// **'Dosis por toma: {dose}'**
  String treatmentSummaryDosePerIntake(int dose);

  /// No description provided for @treatmentSummaryRemainingIntakes.
  ///
  /// In es, this message translates to:
  /// **'Tomas restantes: {count}'**
  String treatmentSummaryRemainingIntakes(int count);

  /// No description provided for @treatmentSummaryNotes.
  ///
  /// In es, this message translates to:
  /// **'Notas'**
  String get treatmentSummaryNotes;

  /// No description provided for @treatmentSummaryNoNotes.
  ///
  /// In es, this message translates to:
  /// **'• Ninguna'**
  String get treatmentSummaryNoNotes;

  /// No description provided for @treatmentSummaryDownloadPdfTooltip.
  ///
  /// In es, this message translates to:
  /// **'Descargar PDF'**
  String get treatmentSummaryDownloadPdfTooltip;

  /// No description provided for @addPrescriptionTitle.
  ///
  /// In es, this message translates to:
  /// **'Agregar Receta'**
  String get addPrescriptionTitle;

  /// No description provided for @editTreatmentTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar Tratamiento'**
  String get editTreatmentTitle;

  /// No description provided for @addPrescriptionAiScanTooltip.
  ///
  /// In es, this message translates to:
  /// **'Escanear receta con IA'**
  String get addPrescriptionAiScanTooltip;

  /// No description provided for @addPrescriptionStep0Question.
  ///
  /// In es, this message translates to:
  /// **'¿Qué medicamento vas a agregar?'**
  String get addPrescriptionStep0Question;

  /// No description provided for @addPrescriptionStep0QuestionAnimal.
  ///
  /// In es, this message translates to:
  /// **'¿Qué medicamento o tratamiento vas a agregar?'**
  String get addPrescriptionStep0QuestionAnimal;

  /// No description provided for @addPrescriptionStep0Label.
  ///
  /// In es, this message translates to:
  /// **'Nombre del medicamento'**
  String get addPrescriptionStep0Label;

  /// No description provided for @addPrescriptionStep0LabelAnimal.
  ///
  /// In es, this message translates to:
  /// **'Nombre del medicamento / tratamiento'**
  String get addPrescriptionStep0LabelAnimal;

  /// No description provided for @addPrescriptionStep0Hint.
  ///
  /// In es, this message translates to:
  /// **'Escribe el nombre del medicamento'**
  String get addPrescriptionStep0Hint;

  /// No description provided for @addPrescriptionStep0HintAnimal.
  ///
  /// In es, this message translates to:
  /// **'Escribe el nombre del fármaco o tratamiento'**
  String get addPrescriptionStep0HintAnimal;

  /// No description provided for @addPrescriptionPetPrefix.
  ///
  /// In es, this message translates to:
  /// **'Mascota: {name}'**
  String addPrescriptionPetPrefix(String name);

  /// No description provided for @addPrescriptionPatientPrefix.
  ///
  /// In es, this message translates to:
  /// **'Paciente: {name}'**
  String addPrescriptionPatientPrefix(String name);

  /// No description provided for @addPrescriptionStep1Question.
  ///
  /// In es, this message translates to:
  /// **'¿Cuál es la presentación del medicamento?'**
  String get addPrescriptionStep1Question;

  /// No description provided for @addPrescriptionStep1Hint.
  ///
  /// In es, this message translates to:
  /// **'Selecciona una opción'**
  String get addPrescriptionStep1Hint;

  /// No description provided for @addPrescriptionStep2Question.
  ///
  /// In es, this message translates to:
  /// **'¿Cuándo será la primera dosis?'**
  String get addPrescriptionStep2Question;

  /// No description provided for @addPrescriptionStep2SelectedTime.
  ///
  /// In es, this message translates to:
  /// **'Hora seleccionada: {time}'**
  String addPrescriptionStep2SelectedTime(String time);

  /// No description provided for @addPrescriptionStep3Question.
  ///
  /// In es, this message translates to:
  /// **'¿Con qué frecuencia lo tomarás?'**
  String get addPrescriptionStep3Question;

  /// No description provided for @addPrescriptionStep3QuestionAnimal.
  ///
  /// In es, this message translates to:
  /// **'¿Con qué frecuencia se administrará?'**
  String get addPrescriptionStep3QuestionAnimal;

  /// No description provided for @addPrescriptionStep3SelectedHours.
  ///
  /// In es, this message translates to:
  /// **'Cada {hours} horas'**
  String addPrescriptionStep3SelectedHours(int hours);

  /// No description provided for @addPrescriptionStep4Question.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto tiempo durará el tratamiento?'**
  String get addPrescriptionStep4Question;

  /// No description provided for @addPrescriptionStep5Question.
  ///
  /// In es, this message translates to:
  /// **'¿Tienes medicamentos en inventario?'**
  String get addPrescriptionStep5Question;

  /// No description provided for @addPrescriptionStep6Question.
  ///
  /// In es, this message translates to:
  /// **'¿Quieres añadir alguna nota o indicación médica?'**
  String get addPrescriptionStep6Question;

  /// No description provided for @addPrescriptionStep6NotesHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe aquí notas adicionales...'**
  String get addPrescriptionStep6NotesHint;

  /// No description provided for @addPrescriptionStep7Summary.
  ///
  /// In es, this message translates to:
  /// **'Resumen del tratamiento'**
  String get addPrescriptionStep7Summary;

  /// No description provided for @addPrescriptionSavedSuccess.
  ///
  /// In es, this message translates to:
  /// **'Tratamiento guardado exitosamente'**
  String get addPrescriptionSavedSuccess;

  /// No description provided for @addPrescriptionUpdatedSuccess.
  ///
  /// In es, this message translates to:
  /// **'Tratamiento actualizado exitosamente'**
  String get addPrescriptionUpdatedSuccess;

  /// No description provided for @addPrescriptionSaveError.
  ///
  /// In es, this message translates to:
  /// **'Error al guardar el tratamiento'**
  String get addPrescriptionSaveError;

  /// No description provided for @chatBotWelcome.
  ///
  /// In es, this message translates to:
  /// **'¡Hola! Soy Midi, tu asistente virtual de MediTime. Estoy aquí para ayudarte a organizar tus medicamentos, recordarte tus dosis o responder cualquier duda que tengas sobre la aplicación. ¿En qué te puedo ayudar hoy?'**
  String get chatBotWelcome;

  /// No description provided for @chatBotAskAbout.
  ///
  /// In es, this message translates to:
  /// **'Puedes preguntarme sobre:'**
  String get chatBotAskAbout;

  /// No description provided for @chatBotQuickMeds.
  ///
  /// In es, this message translates to:
  /// **'Mis medicamentos'**
  String get chatBotQuickMeds;

  /// No description provided for @chatBotQuickMedsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Info, dosis y horarios'**
  String get chatBotQuickMedsSubtitle;

  /// No description provided for @chatBotQuickReminders.
  ///
  /// In es, this message translates to:
  /// **'Recordatorios'**
  String get chatBotQuickReminders;

  /// No description provided for @chatBotQuickRemindersSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Alarmas y notificaciones'**
  String get chatBotQuickRemindersSubtitle;

  /// No description provided for @chatBotQuickProgress.
  ///
  /// In es, this message translates to:
  /// **'Mi progreso'**
  String get chatBotQuickProgress;

  /// No description provided for @chatBotQuickProgressSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Adherencia y estadísticas'**
  String get chatBotQuickProgressSubtitle;

  /// No description provided for @chatBotQuickFaq.
  ///
  /// In es, this message translates to:
  /// **'Dudas frecuentes'**
  String get chatBotQuickFaq;

  /// No description provided for @chatBotQuickFaqSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Resuelve tus preguntas'**
  String get chatBotQuickFaqSubtitle;

  /// No description provided for @chatBotMedicalDisclaimer.
  ///
  /// In es, this message translates to:
  /// **'Midi no reemplaza la opinión médica profesional. Ante cualquier duda de salud, consulta a tu médico.'**
  String get chatBotMedicalDisclaimer;

  /// No description provided for @chatBotInputHint.
  ///
  /// In es, this message translates to:
  /// **'Pregunta lo que necesitas...'**
  String get chatBotInputHint;

  /// No description provided for @profileTitle.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get profileTitle;

  /// No description provided for @profileBirthDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha de nacimiento'**
  String get profileBirthDate;

  /// No description provided for @profileBloodType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de sangre'**
  String get profileBloodType;

  /// No description provided for @profileAllergies.
  ///
  /// In es, this message translates to:
  /// **'Alergias'**
  String get profileAllergies;

  /// No description provided for @profileNotSpecified.
  ///
  /// In es, this message translates to:
  /// **'No especificado'**
  String get profileNotSpecified;

  /// No description provided for @profilePersonalData.
  ///
  /// In es, this message translates to:
  /// **'Datos Personales'**
  String get profilePersonalData;

  /// No description provided for @profileName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get profileName;

  /// No description provided for @profileNameHint.
  ///
  /// In es, this message translates to:
  /// **'Tu nombre completo'**
  String get profileNameHint;

  /// No description provided for @profilePhone.
  ///
  /// In es, this message translates to:
  /// **'Número de Teléfono'**
  String get profilePhone;

  /// No description provided for @profilePhoneHint.
  ///
  /// In es, this message translates to:
  /// **'Tu número de teléfono'**
  String get profilePhoneHint;

  /// No description provided for @profileEmail.
  ///
  /// In es, this message translates to:
  /// **'Correo'**
  String get profileEmail;

  /// No description provided for @profileEmailHint.
  ///
  /// In es, this message translates to:
  /// **'Tu correo electrónico'**
  String get profileEmailHint;

  /// No description provided for @profileDob.
  ///
  /// In es, this message translates to:
  /// **'Fecha de Nacimiento'**
  String get profileDob;

  /// No description provided for @profileMedicalData.
  ///
  /// In es, this message translates to:
  /// **'Datos Médicos'**
  String get profileMedicalData;

  /// No description provided for @profileBloodTypeHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: O+'**
  String get profileBloodTypeHint;

  /// No description provided for @profileAllergiesHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Penicilina'**
  String get profileAllergiesHint;

  /// No description provided for @profileImportantMeds.
  ///
  /// In es, this message translates to:
  /// **'Medicamentos Importantes'**
  String get profileImportantMeds;

  /// No description provided for @profileImportantMedsHint.
  ///
  /// In es, this message translates to:
  /// **'Los que tomas regularmente'**
  String get profileImportantMedsHint;

  /// No description provided for @profileMedicalHistory.
  ///
  /// In es, this message translates to:
  /// **'Historial Médico'**
  String get profileMedicalHistory;

  /// No description provided for @profileMedicalHistoryHint.
  ///
  /// In es, this message translates to:
  /// **'Condiciones médicas relevantes'**
  String get profileMedicalHistoryHint;

  /// No description provided for @profileNearbyPharmacies.
  ///
  /// In es, this message translates to:
  /// **'Farmacias Cercanas'**
  String get profileNearbyPharmacies;

  /// No description provided for @profileNearbyPharmaciesSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Buscar farmacias en el mapa'**
  String get profileNearbyPharmaciesSubtitle;

  /// No description provided for @profileInfoBannerTitle.
  ///
  /// In es, this message translates to:
  /// **'Información Importante'**
  String get profileInfoBannerTitle;

  /// No description provided for @profileInfoBannerText.
  ///
  /// In es, this message translates to:
  /// **'Mantener tus datos personales y médicos actualizados permite una mejor asistencia en caso de emergencias médicas.'**
  String get profileInfoBannerText;

  /// No description provided for @profileSaveSuccess.
  ///
  /// In es, this message translates to:
  /// **'Perfil actualizado exitosamente'**
  String get profileSaveSuccess;

  /// No description provided for @profileSaveButton.
  ///
  /// In es, this message translates to:
  /// **'Guardar Cambios'**
  String get profileSaveButton;

  /// No description provided for @reportsLoginRequired.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión para ver tus reportes.'**
  String get reportsLoginRequired;

  /// No description provided for @reportsLoadError.
  ///
  /// In es, this message translates to:
  /// **'Error al cargar los datos para el reporte.'**
  String get reportsLoadError;

  /// No description provided for @reportsNoTreatments.
  ///
  /// In es, this message translates to:
  /// **'No hay tratamientos para generar un reporte.'**
  String get reportsNoTreatments;

  /// No description provided for @reportsQuickSummary.
  ///
  /// In es, this message translates to:
  /// **'Resumen Rápido'**
  String get reportsQuickSummary;

  /// No description provided for @reportsScheduledDoses.
  ///
  /// In es, this message translates to:
  /// **'Programadas'**
  String get reportsScheduledDoses;

  /// No description provided for @reportsTakenDoses.
  ///
  /// In es, this message translates to:
  /// **'Tomadas'**
  String get reportsTakenDoses;

  /// No description provided for @reportsSkippedDoses.
  ///
  /// In es, this message translates to:
  /// **'Omitidas'**
  String get reportsSkippedDoses;

  /// No description provided for @reportsNotifiedDoses.
  ///
  /// In es, this message translates to:
  /// **'Notificadas'**
  String get reportsNotifiedDoses;

  /// No description provided for @reportsSnoozedDoses.
  ///
  /// In es, this message translates to:
  /// **'Aplazadas'**
  String get reportsSnoozedDoses;

  /// No description provided for @tutorialTapToContinue.
  ///
  /// In es, this message translates to:
  /// **'Toca para continuar'**
  String get tutorialTapToContinue;

  /// No description provided for @tutorialSkip.
  ///
  /// In es, this message translates to:
  /// **'Saltar'**
  String get tutorialSkip;

  /// No description provided for @tutorialStep1Title.
  ///
  /// In es, this message translates to:
  /// **'Menú Principal'**
  String get tutorialStep1Title;

  /// No description provided for @tutorialStep1Desc.
  ///
  /// In es, this message translates to:
  /// **'Accede al menú lateral para ver tu Perfil, Reportes de Adherencia en PDF, gestionar Pacientes (Modo Cuidador) y ajustar Notificaciones.'**
  String get tutorialStep1Desc;

  /// No description provided for @tutorialStep2Title.
  ///
  /// In es, this message translates to:
  /// **'Midi, tu Asistente Virtual'**
  String get tutorialStep2Title;

  /// No description provided for @tutorialStep2Desc.
  ///
  /// In es, this message translates to:
  /// **'Conoce a Midi, tu asistente inteligente. Chatea con él para resolver dudas sobre medicamentos, dosis, efectos secundarios e interacciones.'**
  String get tutorialStep2Desc;

  /// No description provided for @tutorialStep3Title.
  ///
  /// In es, this message translates to:
  /// **'Resumen Diario'**
  String get tutorialStep3Title;

  /// No description provided for @tutorialStep3Desc.
  ///
  /// In es, this message translates to:
  /// **'Monitorea tu nivel de adherencia hoy y visualiza de un vistazo las dosis pendientes y tomadas del día.'**
  String get tutorialStep3Desc;

  /// No description provided for @tutorialStep4Title.
  ///
  /// In es, this message translates to:
  /// **'Selector de Fechas'**
  String get tutorialStep4Title;

  /// No description provided for @tutorialStep4Desc.
  ///
  /// In es, this message translates to:
  /// **'Navega en el tiempo: toca la fecha para planificar o registrar medicamentos de días anteriores o futuros.'**
  String get tutorialStep4Desc;

  /// No description provided for @tutorialStep5Title.
  ///
  /// In es, this message translates to:
  /// **'Agregar Receta o Tratamiento'**
  String get tutorialStep5Title;

  /// No description provided for @tutorialStep5Desc.
  ///
  /// In es, this message translates to:
  /// **'Toca el botón + para registrar nuevos medicamentos, definir frecuencias de tomas y configurar recordatorios automáticos.'**
  String get tutorialStep5Desc;

  /// No description provided for @tutorialStep6Title.
  ///
  /// In es, this message translates to:
  /// **'Pestaña Calendario'**
  String get tutorialStep6Title;

  /// No description provided for @tutorialStep6Desc.
  ///
  /// In es, this message translates to:
  /// **'Accede al Calendario interactivo para ver tu historial de tomas organizado día por día.'**
  String get tutorialStep6Desc;

  /// No description provided for @tutorialStep7Title.
  ///
  /// In es, this message translates to:
  /// **'Historial y Detalle del Día'**
  String get tutorialStep7Title;

  /// No description provided for @tutorialStep7Desc.
  ///
  /// In es, this message translates to:
  /// **'Revisa cada día según tus dosis:\n🟢 Tomadas  🔴 Omitidas  🟡 Pendientes\n\nToca cualquier día para ver la lista de dosis programadas.'**
  String get tutorialStep7Desc;

  /// No description provided for @tutorialStep8Title.
  ///
  /// In es, this message translates to:
  /// **'Pestaña Mi Progreso'**
  String get tutorialStep8Title;

  /// No description provided for @tutorialStep8Desc.
  ///
  /// In es, this message translates to:
  /// **'Accede a la pestaña Progreso para analizar tus estadísticas de salud, cumplimiento acumulado y rachas.'**
  String get tutorialStep8Desc;

  /// No description provided for @tutorialStep9Title.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas y Modo Cuidador'**
  String get tutorialStep9Title;

  /// No description provided for @tutorialStep9Desc.
  ///
  /// In es, this message translates to:
  /// **'Mide tu porcentaje general de adherencia, dosis tomadas vs omitidas y el cumplimiento por paciente si usas el Modo Cuidador.'**
  String get tutorialStep9Desc;

  /// No description provided for @tutorialStep10Title.
  ///
  /// In es, this message translates to:
  /// **'Filtros y Resumen Desplegable'**
  String get tutorialStep10Title;

  /// No description provided for @tutorialStep10Desc.
  ///
  /// In es, this message translates to:
  /// **'Filtra tu progreso por Semana, Mes o Año. Usa \"Ver más\" para desplegar la lista y cambia el orden entre \"Más recientes\" y \"Más antiguos\".'**
  String get tutorialStep10Desc;

  /// No description provided for @tutorialStep11Title.
  ///
  /// In es, this message translates to:
  /// **'Navegación Principal'**
  String get tutorialStep11Title;

  /// No description provided for @tutorialStep11Desc.
  ///
  /// In es, this message translates to:
  /// **'¡Todo listo! Usa la barra inferior para moverte cómodamente entre Receta, Calendario y Mi Progreso.'**
  String get tutorialStep11Desc;

  /// No description provided for @treatmentSummaryFrequency.
  ///
  /// In es, this message translates to:
  /// **'Frecuencia'**
  String get treatmentSummaryFrequency;

  /// No description provided for @durationDays.
  ///
  /// In es, this message translates to:
  /// **'Días'**
  String get durationDays;

  /// No description provided for @durationMonths.
  ///
  /// In es, this message translates to:
  /// **'Meses'**
  String get durationMonths;

  /// No description provided for @durationYears.
  ///
  /// In es, this message translates to:
  /// **'Años'**
  String get durationYears;

  /// No description provided for @durationIndefinite.
  ///
  /// In es, this message translates to:
  /// **'Indefinido'**
  String get durationIndefinite;

  /// No description provided for @durationTreatmentDuration.
  ///
  /// In es, this message translates to:
  /// **'Duración del tratamiento'**
  String get durationTreatmentDuration;

  /// No description provided for @durationIndefiniteTitle.
  ///
  /// In es, this message translates to:
  /// **'Tratamiento Indefinido - Optimizado'**
  String get durationIndefiniteTitle;

  /// No description provided for @durationIndefiniteBullet1.
  ///
  /// In es, this message translates to:
  /// **'• Las dosis se generan automáticamente según sea necesario'**
  String get durationIndefiniteBullet1;

  /// No description provided for @durationIndefiniteBullet2.
  ///
  /// In es, this message translates to:
  /// **'• Mejor rendimiento en el calendario y la aplicación'**
  String get durationIndefiniteBullet2;

  /// No description provided for @durationIndefiniteBullet3.
  ///
  /// In es, this message translates to:
  /// **'• Puedes pausar o detener el tratamiento en cualquier momento'**
  String get durationIndefiniteBullet3;

  /// No description provided for @addPrescriptionStep3Label.
  ///
  /// In es, this message translates to:
  /// **'Intervalo entre dosis'**
  String get addPrescriptionStep3Label;

  /// No description provided for @addPrescriptionStep3Hint.
  ///
  /// In es, this message translates to:
  /// **'Ej: 8 (cada 8 horas)'**
  String get addPrescriptionStep3Hint;

  /// No description provided for @addPrescriptionCurrentStock.
  ///
  /// In es, this message translates to:
  /// **'Cantidad actual'**
  String get addPrescriptionCurrentStock;

  /// No description provided for @addPrescriptionBoxStock.
  ///
  /// In es, this message translates to:
  /// **'Cantidad total por caja'**
  String get addPrescriptionBoxStock;

  /// No description provided for @addPrescriptionDosePerTake.
  ///
  /// In es, this message translates to:
  /// **'Dosis por toma'**
  String get addPrescriptionDosePerTake;

  /// No description provided for @addPrescriptionStep6Examples.
  ///
  /// In es, this message translates to:
  /// **'(Ej: \"Tomar con comida\", \"No conducir\")'**
  String get addPrescriptionStep6Examples;

  /// No description provided for @addPrescriptionStep6NotesLabel.
  ///
  /// In es, this message translates to:
  /// **'Notas (Opcional)'**
  String get addPrescriptionStep6NotesLabel;

  /// No description provided for @addPrescriptionStep7Review.
  ///
  /// In es, this message translates to:
  /// **'Revisa los datos antes de confirmar'**
  String get addPrescriptionStep7Review;

  /// No description provided for @addPrescriptionStep7AlarmNotice.
  ///
  /// In es, this message translates to:
  /// **'Al confirmar, se programarán las alarmas automáticamente para recordarte cada dosis'**
  String get addPrescriptionStep7AlarmNotice;

  /// No description provided for @addPrescriptionTreatmentUpdated.
  ///
  /// In es, this message translates to:
  /// **'Tratamiento actualizado para {medicine}'**
  String addPrescriptionTreatmentUpdated(String medicine);

  /// No description provided for @addPrescriptionRemindersConfigured.
  ///
  /// In es, this message translates to:
  /// **'Recordatorios configurados para {medicine}'**
  String addPrescriptionRemindersConfigured(String medicine);

  /// No description provided for @chatBotRecordingNotice.
  ///
  /// In es, this message translates to:
  /// **'Grabando... Toca el mic para enviar'**
  String get chatBotRecordingNotice;

  /// No description provided for @chatBotCancelRecording.
  ///
  /// In es, this message translates to:
  /// **'Cancelar grabación'**
  String get chatBotCancelRecording;

  /// No description provided for @chatBotTakeRecipePhoto.
  ///
  /// In es, this message translates to:
  /// **'Tomar Foto de la Receta'**
  String get chatBotTakeRecipePhoto;

  /// No description provided for @helpSupport.
  ///
  /// In es, this message translates to:
  /// **'Ayuda y Soporte'**
  String get helpSupport;

  /// No description provided for @helpGuideTitle.
  ///
  /// In es, this message translates to:
  /// **'Guía de Optimización de Recordatorios'**
  String get helpGuideTitle;

  /// No description provided for @helpGuideSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Evita que el ahorro de batería o el sistema silencien tus alarmas. Diagnóstico en vivo y accesos directos a configuraciones.'**
  String get helpGuideSubtitle;

  /// No description provided for @helpHowToUseTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo usar la aplicación?'**
  String get helpHowToUseTitle;

  /// No description provided for @helpHowToUseSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Aprende a registrar tratamientos, horarios e inventario.'**
  String get helpHowToUseSubtitle;

  /// No description provided for @helpTermsTitle.
  ///
  /// In es, this message translates to:
  /// **'Términos de uso'**
  String get helpTermsTitle;

  /// No description provided for @helpTermsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Condiciones de servicio y responsabilidades.'**
  String get helpTermsSubtitle;

  /// No description provided for @helpPrivacyTitle.
  ///
  /// In es, this message translates to:
  /// **'Política de Privacidad'**
  String get helpPrivacyTitle;

  /// No description provided for @helpPrivacySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Cómo tratamos y protegemos tus datos médicos.'**
  String get helpPrivacySubtitle;

  /// No description provided for @helpAppVersionTitle.
  ///
  /// In es, this message translates to:
  /// **'Versión de la aplicación'**
  String get helpAppVersionTitle;

  /// No description provided for @helpAppVersionSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Información de la versión y compilación actual.'**
  String get helpAppVersionSubtitle;

  /// No description provided for @helpDevelopersTitle.
  ///
  /// In es, this message translates to:
  /// **'Desarrolladores'**
  String get helpDevelopersTitle;

  /// No description provided for @helpDevelopersSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Equipo creador y créditos del proyecto.'**
  String get helpDevelopersSubtitle;

  /// No description provided for @helpUnderstood.
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get helpUnderstood;

  /// No description provided for @helpLoadingVersion.
  ///
  /// In es, this message translates to:
  /// **'Cargando versión...'**
  String get helpLoadingVersion;

  /// No description provided for @helpVersionText.
  ///
  /// In es, this message translates to:
  /// **'MediTime versión {version} (Build {buildNumber}).'**
  String helpVersionText(String version, String buildNumber);

  /// No description provided for @helpProgramming.
  ///
  /// In es, this message translates to:
  /// **'Programación:'**
  String get helpProgramming;

  /// No description provided for @helpDesign.
  ///
  /// In es, this message translates to:
  /// **'Diseño:'**
  String get helpDesign;

  /// No description provided for @helpTesting.
  ///
  /// In es, this message translates to:
  /// **'Testing:'**
  String get helpTesting;

  /// No description provided for @helpSpecialThanks.
  ///
  /// In es, this message translates to:
  /// **'Agradecimientos Especiales a la Universidad de Cundinamarca seccional Ubaté por incentivar el desarrollo de proyectos innovadores y el acompañamiento por parte de los docentes y directivos.\n\nUniversidad de Cundinamarca\nIngeniería en Sistemas y Computación\n©Todos los Derechos Reservados\n2022-2026'**
  String get helpSpecialThanks;

  /// No description provided for @reportsEvolutionTitle.
  ///
  /// In es, this message translates to:
  /// **'Evolución de adherencia'**
  String get reportsEvolutionTitle;

  /// No description provided for @reportsSeeMore.
  ///
  /// In es, this message translates to:
  /// **'Ver más'**
  String get reportsSeeMore;

  /// No description provided for @reportsBreakdownTitle.
  ///
  /// In es, this message translates to:
  /// **'Desglose por tratamiento'**
  String get reportsBreakdownTitle;

  /// No description provided for @reportsNoTreatmentsInPeriod.
  ///
  /// In es, this message translates to:
  /// **'No hay tratamientos registrados en este período.'**
  String get reportsNoTreatmentsInPeriod;

  /// No description provided for @reportsSeeLess.
  ///
  /// In es, this message translates to:
  /// **'Ver menos'**
  String get reportsSeeLess;

  /// No description provided for @reportsSeeAll.
  ///
  /// In es, this message translates to:
  /// **'Ver todo'**
  String get reportsSeeAll;

  /// No description provided for @reportsRecentHistoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Historial reciente'**
  String get reportsRecentHistoryTitle;

  /// No description provided for @reportsNoRecentRecords.
  ///
  /// In es, this message translates to:
  /// **'No hay registros recientes.'**
  String get reportsNoRecentRecords;

  /// No description provided for @reportsOmissionsPatternTitle.
  ///
  /// In es, this message translates to:
  /// **'Patrón de omisiones'**
  String get reportsOmissionsPatternTitle;

  /// No description provided for @reportsSeeAnalysis.
  ///
  /// In es, this message translates to:
  /// **'Ver análisis'**
  String get reportsSeeAnalysis;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @chatBotSelectFromGallery.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar de la galería'**
  String get chatBotSelectFromGallery;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
