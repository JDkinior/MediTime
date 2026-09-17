// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MediTime';

  @override
  String get commonAccept => 'Accept';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonClose => 'Close';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonError => 'Error';

  @override
  String get commonSuccess => 'Success';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonRetry => 'Retry';

  @override
  String get navHome => 'Home';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navMedications => 'Medications';

  @override
  String get navPrescription => 'Prescriptions';

  @override
  String get navProgress => 'Progress';

  @override
  String get navProfile => 'Profile';

  @override
  String get navChatBot => 'Midi Chat';

  @override
  String get appBarProgress => 'My Progress';

  @override
  String get appBarCalendar => 'Calendar';

  @override
  String get appBarMedications => 'Medications';

  @override
  String get appBarProfile => 'My Profile';

  @override
  String get appBarAdherenceReport => 'Adherence Report';

  @override
  String get appBarHelp => 'Help & Support';

  @override
  String get drawerCaregiverMode => 'Caregiver Mode';

  @override
  String get drawerSectionMain => 'MAIN';

  @override
  String get drawerProfile => 'My Profile';

  @override
  String get drawerProfileSubtitle => 'View and edit your info';

  @override
  String get drawerAdherenceReport => 'Adherence Report';

  @override
  String get drawerAdherenceReportSubtitle => 'Statistics and reports';

  @override
  String get drawerOptions => 'Settings';

  @override
  String get drawerOptionsSubtitle => 'App settings';

  @override
  String get drawerSectionHelp => 'HELP';

  @override
  String get drawerHelp => 'Help';

  @override
  String get drawerHelpSubtitle => 'Help and support center';

  @override
  String get drawerTutorial => 'Tutorial';

  @override
  String get drawerTutorialSubtitle => 'Guides and usage tips';

  @override
  String get drawerChatbot => 'MediTime Chatbot';

  @override
  String get drawerChatbotSubtitle => 'Smart assistant';

  @override
  String get drawerSectionManage => 'MANAGEMENT';

  @override
  String get drawerManagePatients => 'Manage Patients';

  @override
  String get drawerManagePatientsSubtitle => 'Add, edit or delete';

  @override
  String get drawerCaregiverSettings => 'Caregiver Settings';

  @override
  String get drawerCaregiverSettingsSubtitle => 'Caregiver mode preferences';

  @override
  String get drawerLogout => 'Log Out';

  @override
  String get drawerLogoutSubtitle => 'Sign out of your account';

  @override
  String get optionsTitle => 'Settings';

  @override
  String get optionsAccessibility => 'Accessibility';

  @override
  String get optionsAccessibilitySubtitle =>
      'Hide secondary options and focus on what matters most.';

  @override
  String get optionsAppearance => 'Design & Appearance';

  @override
  String get optionsAppearanceSubtitle =>
      'Customize the app appearance to your liking.';

  @override
  String get optionsNotifications => 'Notifications & Alarms';

  @override
  String get optionsNotificationsSubtitle =>
      'Configure how you want to receive your reminders.';

  @override
  String get optionsPrivacy => 'Data & Privacy';

  @override
  String get optionsPrivacySubtitle => 'Manage your medical and chat history.';

  @override
  String get optionsCaregiver => 'Caregiver Mode';

  @override
  String get optionsCaregiverSubtitle =>
      'Configure multi-profile management for family or clinical care.';

  @override
  String get optionsAnimals => 'Animal Mode (Veterinary)';

  @override
  String get optionsAnimalsSubtitle =>
      'Adapt the app for veterinary clinics and pets (single or multiple).';

  @override
  String get drawerAnimalsMode => 'Animal Mode';

  @override
  String get drawerManageAnimals => 'Manage Pets / Animals';

  @override
  String get drawerManageAnimalsSubtitle => 'Add, edit or dismiss';

  @override
  String get drawerAnimalsSettings => 'Animal Mode Settings';

  @override
  String get drawerAnimalsSettingsSubtitle => 'Veterinary and pet preferences';

  @override
  String get optionsLanguage => 'Language';

  @override
  String get optionsLanguageSubtitle => 'Select the application language.';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSubtitle => 'Select your preferred interface language.';

  @override
  String get languageSystem => 'Automatic (System)';

  @override
  String get languageSystemDesc => 'Follow device settings';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageSpanishDesc => 'Spanish (default)';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageEnglishDesc => 'English';

  @override
  String get languageChangedSnackbar => 'Language updated successfully.';

  @override
  String get homeGreetingMorning => 'Good morning!';

  @override
  String get homeGreetingAfternoon => 'Good afternoon!';

  @override
  String get homeGreetingEvening => 'Good evening!';

  @override
  String get homeNextDose => 'Next dose';

  @override
  String get homeTodayDoses => 'Today\'s doses';

  @override
  String get homeCompleted => 'Completed';

  @override
  String get homePending => 'Pending';

  @override
  String get homeNoPendingDoses => 'You have no pending doses for now.';

  @override
  String get homeAddTreatment => 'Add Treatment';

  @override
  String helloUser(String name) {
    return 'Hello, $name';
  }

  @override
  String get planForToday => 'Here is your plan for today';

  @override
  String get planForDay => 'Here is your plan for this day';

  @override
  String get summaryToday => 'Today\'s summary';

  @override
  String get summaryDay => 'Day\'s summary';

  @override
  String get pendingUppercase => 'PENDING';

  @override
  String get takenUppercase => 'TAKEN';

  @override
  String get adherenceUppercase => 'ADHERENCE';

  @override
  String get upcomingDoses => 'Upcoming doses';

  @override
  String get dosesOfTheDay => 'Doses of the day';

  @override
  String get noDosesToday => 'You have no doses scheduled for today.';

  @override
  String get noDosesDay => 'You have no doses scheduled for this day.';

  @override
  String everyHours(int hours) {
    return 'Every $hours hours';
  }

  @override
  String get everyHourSingle => 'Every hour';

  @override
  String get actionTake => 'Take';

  @override
  String get actionSkip => 'Skip';

  @override
  String get actionSnooze => 'Snooze';

  @override
  String get doseTakenSuccess => 'Dose marked as taken successfully';

  @override
  String get doseSkippedSuccess => 'Dose skipped';

  @override
  String doseSnoozedSuccess(int minutes) {
    return 'Dose snoozed for $minutes minutes';
  }

  @override
  String get doseStatusPending => 'Pending';

  @override
  String get doseStatusNotified => 'Notified';

  @override
  String get doseStatusTaken => 'Taken';

  @override
  String get doseStatusSkipped => 'Skipped';

  @override
  String get doseStatusSnoozed => 'Snoozed';

  @override
  String get doseStatusScheduled => 'Scheduled';

  @override
  String get presentationComprimidos => 'Tablets';

  @override
  String get presentationGrageas => 'Dragees';

  @override
  String get presentationCapsulas => 'Capsules';

  @override
  String get presentationSobres => 'Sachets';

  @override
  String get presentationJarabes => 'Syrups';

  @override
  String get presentationGotas => 'Drops';

  @override
  String get presentationSuspensiones => 'Suspensions';

  @override
  String get presentationEmulsiones => 'Emulsions';

  @override
  String get daySummary => 'Day summary';

  @override
  String dosesCompletedSummary(int taken, int total) {
    return '$taken of $total doses completed';
  }

  @override
  String get medicationsOfTheDay => 'Today\'s medications';

  @override
  String get treatmentDetailTitle => 'Treatment Details';

  @override
  String get treatmentMedicineName => 'Medication';

  @override
  String get treatmentDose => 'Dose';

  @override
  String get treatmentFrequency => 'Frequency';

  @override
  String get treatmentInstructions => 'Instructions';

  @override
  String get treatmentActive => 'Active';

  @override
  String get treatmentFinished => 'Finished';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get calendarToday => 'Today';

  @override
  String get calendarNoEvents => 'No doses scheduled for this day.';

  @override
  String get intervalWeek => 'Week';

  @override
  String get intervalMonth => 'Month';

  @override
  String get intervalYear => 'Year';

  @override
  String get intervalAll => 'All';

  @override
  String get overallPerformance => 'Your overall performance';

  @override
  String get adherence => 'Adherence';

  @override
  String get taken => 'Taken';

  @override
  String get skipped => 'Skipped';

  @override
  String get activeStreak => 'Active streak';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days',
      one: 'day',
    );
    return '$count $_temp0';
  }

  @override
  String get insightNoDataTitle => 'No data';

  @override
  String get insightNoDataText =>
      'No doses scheduled. Add medications to track your progress.';

  @override
  String get insightGoodTitle => 'Good pace!';

  @override
  String get insightGoodText => 'Small habits, big results. Keep it up!';

  @override
  String get insightAttentionTitle => 'Attention';

  @override
  String get insightAttentionText =>
      'Good pace, but you have had some missed doses.';

  @override
  String get insightAlertTitle => 'Alert!';

  @override
  String get insightAlertText =>
      'Your current adherence level is low. Check your alarms.';

  @override
  String get weekSummary => 'Week summary';

  @override
  String get monthSummary => 'Month summary';

  @override
  String get yearSummary => 'Year summary';

  @override
  String get cumulativeSummary => 'Cumulative summary';

  @override
  String dosesInPeriod(int count) {
    return '$count doses in period';
  }

  @override
  String get mostRecent => 'Most recent';

  @override
  String get oldestFirst => 'Oldest first';

  @override
  String seeMore(int count) {
    return 'See more ($count more doses)';
  }

  @override
  String get seeLess => 'See less';

  @override
  String get complianceWeekly => 'Weekly compliance';

  @override
  String get complianceMonthly => 'Monthly compliance';

  @override
  String get complianceYearly => 'Yearly compliance';

  @override
  String get complianceHistorical => 'Historical compliance';

  @override
  String get complianceWeeklySubtitle => 'Percentage of doses per day';

  @override
  String get complianceMonthlySubtitle => 'Percentage of doses in 5-day blocks';

  @override
  String get complianceYearlySubtitle => 'Percentage of doses per month';

  @override
  String get complianceHistoricalSubtitle =>
      'Percentage of doses in the last 6 months';

  @override
  String get complianceChartTitle => 'Compliance chart';

  @override
  String get progressByPatient => 'Progress by patient';

  @override
  String get chatBotGreeting =>
      'Hello! I am Midi, your health assistant in MediTime.';

  @override
  String get chatBotPlaceholder =>
      'Type a message or ask a medical question...';

  @override
  String get chatBotListening => 'Listening...';

  @override
  String get chatBotClearHistory => 'Clear conversation';
}
