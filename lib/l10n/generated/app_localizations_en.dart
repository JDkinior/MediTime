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

  @override
  String get loginSlogan => 'Manage your medications\nImprove your health';

  @override
  String get loginSignIn => 'Log in';

  @override
  String get loginRegister => 'Sign up';

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginEmailHint => 'Enter your email';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginPasswordHint => 'Enter your password';

  @override
  String get loginButton => 'Log In';

  @override
  String get loginOr => 'or';

  @override
  String get loginWithGoogle => 'Continue with Google';

  @override
  String get loginNoAccount => 'Don\'t have an account? Sign up here';

  @override
  String get loginErrorEmptyEmail => 'Please enter your email';

  @override
  String get loginErrorEmptyPassword => 'Please enter your password';

  @override
  String get loginErrorGeneral => 'Error signing in';

  @override
  String get loginErrorUserNotFound => 'User not found';

  @override
  String get loginErrorWrongPassword => 'Incorrect password';

  @override
  String get loginErrorInvalidEmail => 'Invalid email format';

  @override
  String get loginErrorGoogle =>
      'Error signing in with Google. Please try again.';

  @override
  String get registerTitle => 'Create Account';

  @override
  String get registerSubtitle => 'Start managing your medications';

  @override
  String get registerPasswordHint => 'Create your password';

  @override
  String get registerButton => 'Sign Up';

  @override
  String get registerAlreadyHaveAccount =>
      'Already have an account? Log in here';

  @override
  String get registerErrorInvalidEmail => 'Please enter a valid email';

  @override
  String get registerErrorShortPassword =>
      'Password must be at least 6 characters';

  @override
  String get registerErrorFailed => 'Could not create account';

  @override
  String get registerErrorEmailInUse => 'Email is already in use';

  @override
  String get registerErrorWeakPassword => 'Password is too weak';

  @override
  String get registerErrorGoogle =>
      'Error registering with Google. Please try again.';

  @override
  String get doseDetailDoseTime => 'Dose time';

  @override
  String get doseDetailTreatmentFinished => 'Treatment Completed';

  @override
  String get doseDetailNoMoreDoses => 'No more doses scheduled.';

  @override
  String get doseDetailNextDosePrompt => 'This is the next dose';

  @override
  String get doseDetailNextAlarm => 'Next Alarm:';

  @override
  String get doseDetailTimeNow => 'It is time to take the dose';

  @override
  String doseDetailInSeconds(int seconds) {
    return 'In $seconds seconds';
  }

  @override
  String doseDetailInDaysHours(int days, int hours) {
    return 'In $days days and $hours hours';
  }

  @override
  String doseDetailInHoursMinutes(int hours, int minutes) {
    return 'In $hours hours and $minutes minutes';
  }

  @override
  String doseDetailInMinutes(int minutes) {
    return 'In $minutes minutes';
  }

  @override
  String get doseDetailUpdateError => 'Error updating dose';

  @override
  String get treatmentSummaryMedicine => 'Medication';

  @override
  String treatmentSummaryPresentation(String presentation) {
    return 'Presentation: $presentation';
  }

  @override
  String get treatmentSummarySchedules => 'Schedules';

  @override
  String get treatmentSummaryDuration => 'Duration';

  @override
  String get treatmentSummaryNotDefined => '• Not defined';

  @override
  String treatmentSummaryDaysInParentheses(int days) {
    return '($days days)';
  }

  @override
  String treatmentSummaryEveryHours(int hours) {
    return 'Every $hours hours';
  }

  @override
  String get treatmentSummaryAutoGenerated => '• Doses generated automatically';

  @override
  String treatmentSummaryTotalDoses(String total) {
    return '• Total $total doses';
  }

  @override
  String treatmentSummaryUntil(String date) {
    return '• Until $date';
  }

  @override
  String get treatmentSummaryStockTitle => 'Inventory & Stock';

  @override
  String treatmentSummaryStockAvailable(int current, int total) {
    return 'Available: $current of $total';
  }

  @override
  String treatmentSummaryDosePerIntake(int dose) {
    return 'Dose per intake: $dose';
  }

  @override
  String treatmentSummaryRemainingIntakes(int count) {
    return 'Remaining intakes: $count';
  }

  @override
  String get treatmentSummaryNotes => 'Notes';

  @override
  String get treatmentSummaryNoNotes => '• None';

  @override
  String get treatmentSummaryDownloadPdfTooltip => 'Download PDF';

  @override
  String get addPrescriptionTitle => 'Add Prescription';

  @override
  String get editTreatmentTitle => 'Edit Treatment';

  @override
  String get addPrescriptionAiScanTooltip => 'Scan prescription with AI';

  @override
  String get addPrescriptionStep0Question => 'What medication will you add?';

  @override
  String get addPrescriptionStep0QuestionAnimal =>
      'What medication or treatment will you add?';

  @override
  String get addPrescriptionStep0Label => 'Medication name';

  @override
  String get addPrescriptionStep0LabelAnimal => 'Medication / treatment name';

  @override
  String get addPrescriptionStep0Hint => 'Enter the medication name';

  @override
  String get addPrescriptionStep0HintAnimal =>
      'Enter the drug or treatment name';

  @override
  String addPrescriptionPetPrefix(String name) {
    return 'Pet: $name';
  }

  @override
  String addPrescriptionPatientPrefix(String name) {
    return 'Patient: $name';
  }

  @override
  String get addPrescriptionStep1Question =>
      'What is the presentation of the medication?';

  @override
  String get addPrescriptionStep1Hint => 'Select an option';

  @override
  String get addPrescriptionStep2Question => 'When will the first dose be?';

  @override
  String addPrescriptionStep2SelectedTime(String time) {
    return 'Selected time: $time';
  }

  @override
  String get addPrescriptionStep3Question => 'How often will you take it?';

  @override
  String get addPrescriptionStep3QuestionAnimal =>
      'How often will it be administered?';

  @override
  String addPrescriptionStep3SelectedHours(int hours) {
    return 'Every $hours hours';
  }

  @override
  String get addPrescriptionStep4Question =>
      'How long will the treatment last?';

  @override
  String get addPrescriptionStep5Question =>
      'Do you have medications in stock?';

  @override
  String get addPrescriptionStep6Question =>
      'Want to add any notes or medical instructions?';

  @override
  String get addPrescriptionStep6NotesHint => 'Enter additional notes here...';

  @override
  String get addPrescriptionStep7Summary => 'Treatment summary';

  @override
  String get addPrescriptionSavedSuccess => 'Treatment saved successfully';

  @override
  String get addPrescriptionUpdatedSuccess => 'Treatment updated successfully';

  @override
  String get addPrescriptionSaveError => 'Error saving treatment';

  @override
  String get chatBotWelcome =>
      'Hello! I am Midi, your MediTime virtual assistant. I\'m here to help you organize your medications, remind you of your doses, or answer any questions you have about the app. How can I help you today?';

  @override
  String get chatBotAskAbout => 'You can ask me about:';

  @override
  String get chatBotQuickMeds => 'My medications';

  @override
  String get chatBotQuickMedsSubtitle => 'Info, doses & schedules';

  @override
  String get chatBotQuickReminders => 'Reminders';

  @override
  String get chatBotQuickRemindersSubtitle => 'Alarms & notifications';

  @override
  String get chatBotQuickProgress => 'My progress';

  @override
  String get chatBotQuickProgressSubtitle => 'Adherence & statistics';

  @override
  String get chatBotQuickFaq => 'FAQ';

  @override
  String get chatBotQuickFaqSubtitle => 'Answer your questions';

  @override
  String get chatBotMedicalDisclaimer =>
      'Midi does not replace professional medical advice. For any health concerns, consult your doctor.';

  @override
  String get chatBotInputHint => 'Ask anything you need...';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileBirthDate => 'Date of birth';

  @override
  String get profileBloodType => 'Blood type';

  @override
  String get profileAllergies => 'Allergies';

  @override
  String get profileNotSpecified => 'Not specified';

  @override
  String get profilePersonalData => 'Personal Information';

  @override
  String get profileName => 'Name';

  @override
  String get profileNameHint => 'Your full name';

  @override
  String get profilePhone => 'Phone Number';

  @override
  String get profilePhoneHint => 'Your phone number';

  @override
  String get profileEmail => 'Email';

  @override
  String get profileEmailHint => 'Your email';

  @override
  String get profileDob => 'Date of Birth';

  @override
  String get profileMedicalData => 'Medical Information';

  @override
  String get profileBloodTypeHint => 'E.g. O+';

  @override
  String get profileAllergiesHint => 'E.g. Penicillin';

  @override
  String get profileImportantMeds => 'Important Medications';

  @override
  String get profileImportantMedsHint => 'The ones you take regularly';

  @override
  String get profileMedicalHistory => 'Medical History';

  @override
  String get profileMedicalHistoryHint => 'Relevant medical conditions';

  @override
  String get profileNearbyPharmacies => 'Nearby Pharmacies';

  @override
  String get profileNearbyPharmaciesSubtitle => 'Search pharmacies on the map';

  @override
  String get profileInfoBannerTitle => 'Important Information';

  @override
  String get profileInfoBannerText =>
      'Keeping your personal and medical data updated helps ensure better assistance during medical emergencies.';

  @override
  String get profileSaveSuccess => 'Profile updated successfully';

  @override
  String get profileSaveButton => 'Save Changes';

  @override
  String get reportsLoginRequired => 'Log in to view your reports.';

  @override
  String get reportsLoadError => 'Error loading report data.';

  @override
  String get reportsNoTreatments => 'No treatments to generate a report.';

  @override
  String get reportsQuickSummary => 'Quick Summary';

  @override
  String get reportsScheduledDoses => 'Scheduled';

  @override
  String get reportsTakenDoses => 'Taken';

  @override
  String get reportsSkippedDoses => 'Skipped';

  @override
  String get reportsNotifiedDoses => 'Notified';

  @override
  String get reportsSnoozedDoses => 'Snoozed';

  @override
  String get tutorialTapToContinue => 'Tap to continue';

  @override
  String get tutorialSkip => 'Skip';

  @override
  String get tutorialStep1Title => 'Main Menu';

  @override
  String get tutorialStep1Desc =>
      'Access the side menu to view your Profile, PDF Adherence Reports, manage Patients (Caregiver Mode), and adjust Notifications.';

  @override
  String get tutorialStep2Title => 'Midi, your Virtual Assistant';

  @override
  String get tutorialStep2Desc =>
      'Meet Midi, your smart assistant. Chat with him to resolve doubts about medications, doses, side effects, and interactions.';

  @override
  String get tutorialStep3Title => 'Daily Summary';

  @override
  String get tutorialStep3Desc =>
      'Monitor your adherence level today and view pending and taken doses of the day at a glance.';

  @override
  String get tutorialStep4Title => 'Date Selector';

  @override
  String get tutorialStep4Desc =>
      'Navigate through time: tap the date to plan or register medications for past or future days.';

  @override
  String get tutorialStep5Title => 'Add Prescription or Treatment';

  @override
  String get tutorialStep5Desc =>
      'Tap the + button to register new medications, define intake frequencies, and set automatic reminders.';

  @override
  String get tutorialStep6Title => 'Calendar Tab';

  @override
  String get tutorialStep6Desc =>
      'Access the interactive Calendar to view your intake history organized day by day.';

  @override
  String get tutorialStep7Title => 'Day History & Details';

  @override
  String get tutorialStep7Desc =>
      'Review each day by your doses:\n🟢 Taken  🔴 Skipped  🟡 Pending\n\nTap any day to see scheduled doses.';

  @override
  String get tutorialStep8Title => 'My Progress Tab';

  @override
  String get tutorialStep8Desc =>
      'Access the Progress tab to analyze your health statistics, cumulative compliance, and streaks.';

  @override
  String get tutorialStep9Title => 'Statistics & Caregiver Mode';

  @override
  String get tutorialStep9Desc =>
      'Measure your overall adherence percentage, taken vs skipped doses, and compliance per patient if using Caregiver Mode.';

  @override
  String get tutorialStep10Title => 'Filters & Collapsible Summary';

  @override
  String get tutorialStep10Desc =>
      'Filter your progress by Week, Month, or Year. Use \"See more\" to expand the list and toggle order between \"Most recent\" and \"Oldest\".';

  @override
  String get tutorialStep11Title => 'Main Navigation';

  @override
  String get tutorialStep11Desc =>
      'All set! Use the bottom bar to easily navigate between Prescription, Calendar, and My Progress.';

  @override
  String get treatmentSummaryFrequency => 'Frequency';

  @override
  String get durationDays => 'Days';

  @override
  String get durationMonths => 'Months';

  @override
  String get durationYears => 'Years';

  @override
  String get durationIndefinite => 'Indefinite';

  @override
  String get durationTreatmentDuration => 'Treatment duration';

  @override
  String get durationIndefiniteTitle => 'Indefinite Treatment - Optimized';

  @override
  String get durationIndefiniteBullet1 =>
      '• Doses are generated automatically as needed';

  @override
  String get durationIndefiniteBullet2 =>
      '• Better performance in calendar and application';

  @override
  String get durationIndefiniteBullet3 =>
      '• You can pause or stop treatment at any time';

  @override
  String get addPrescriptionStep3Label => 'Interval between doses';

  @override
  String get addPrescriptionStep3Hint => 'E.g.: 8 (every 8 hours)';

  @override
  String get addPrescriptionCurrentStock => 'Current quantity';

  @override
  String get addPrescriptionBoxStock => 'Total quantity per box';

  @override
  String get addPrescriptionDosePerTake => 'Dose per intake';

  @override
  String get addPrescriptionStep6Examples =>
      '(E.g.: \"Take with food\", \"Do not drive\")';

  @override
  String get addPrescriptionStep6NotesLabel => 'Notes (Optional)';

  @override
  String get addPrescriptionStep7Review => 'Review details before confirming';

  @override
  String get addPrescriptionStep7AlarmNotice =>
      'Upon confirming, alarms will be scheduled automatically to remind you of each dose';

  @override
  String addPrescriptionTreatmentUpdated(String medicine) {
    return 'Treatment updated for $medicine';
  }

  @override
  String addPrescriptionRemindersConfigured(String medicine) {
    return 'Reminders configured for $medicine';
  }

  @override
  String get chatBotRecordingNotice => 'Recording... Tap the mic to send';

  @override
  String get chatBotCancelRecording => 'Cancel recording';

  @override
  String get chatBotTakeRecipePhoto => 'Take Prescription Photo';

  @override
  String get helpSupport => 'Help & Support';

  @override
  String get helpGuideTitle => 'Reminder Optimization Guide';

  @override
  String get helpGuideSubtitle =>
      'Prevent battery saver or system from muting alarms. Live diagnostics and shortcuts to settings.';

  @override
  String get helpHowToUseTitle => 'How to use the app?';

  @override
  String get helpHowToUseSubtitle =>
      'Learn how to register treatments, schedules, and inventory.';

  @override
  String get helpTermsTitle => 'Terms of Use';

  @override
  String get helpTermsSubtitle => 'Terms of service and responsibilities.';

  @override
  String get helpPrivacyTitle => 'Privacy Policy';

  @override
  String get helpPrivacySubtitle =>
      'How we handle and protect your medical data.';

  @override
  String get helpAppVersionTitle => 'App Version';

  @override
  String get helpAppVersionSubtitle => 'Current version and build information.';

  @override
  String get helpDevelopersTitle => 'Developers';

  @override
  String get helpDevelopersSubtitle => 'Creator team and project credits.';

  @override
  String get helpUnderstood => 'Understood';

  @override
  String get helpLoadingVersion => 'Loading version...';

  @override
  String helpVersionText(String version, String buildNumber) {
    return 'MediTime version $version (Build $buildNumber).';
  }

  @override
  String get helpProgramming => 'Programming:';

  @override
  String get helpDesign => 'Design:';

  @override
  String get helpTesting => 'Testing:';

  @override
  String get helpSpecialThanks =>
      'Special Thanks to the University of Cundinamarca Ubaté branch for encouraging innovative projects and the guidance of teachers and executives.\n\nUniversity of Cundinamarca\nSystems and Computing Engineering\n©All Rights Reserved\n2022-2026';

  @override
  String get reportsEvolutionTitle => 'Adherence Evolution';

  @override
  String get reportsSeeMore => 'See more';

  @override
  String get reportsBreakdownTitle => 'Breakdown by Treatment';

  @override
  String get reportsNoTreatmentsInPeriod =>
      'No treatments registered in this period.';

  @override
  String get reportsSeeLess => 'See less';

  @override
  String get reportsSeeAll => 'See all';

  @override
  String get reportsRecentHistoryTitle => 'Recent History';

  @override
  String get reportsNoRecentRecords => 'No recent records.';

  @override
  String get reportsOmissionsPatternTitle => 'Pattern of Omissions';

  @override
  String get reportsSeeAnalysis => 'View analysis';

  @override
  String get cancel => 'Cancel';

  @override
  String get chatBotSelectFromGallery => 'Select from gallery';
}
