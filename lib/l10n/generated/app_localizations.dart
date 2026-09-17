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
