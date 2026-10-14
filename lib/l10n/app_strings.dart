/// Zentrale Stelle für alle App-Texte
/// Ermöglicht spätere Übersetzung in andere Sprachen
class AppStrings {
  // Verhindert Instanziierung
  AppStrings._();

  // ===================
  // Allgemein
  // ===================
  static const String appName = 'VAGO';
  static const String save = 'Speichern';
  static const String cancel = 'Abbrechen';
  static const String close = 'Schließen';
  static const String ok = 'OK';
  static const String skip = 'Überspringen';
  static const String next = 'Weiter';
  static const String back = 'Zurück';
  static const String error = 'Fehler';
  static const String loading = 'Lädt...';
  static const String comingSoon = 'Kommt bald!';
  static const String understood = 'Verstanden';

  // ===================
  // Einheiten & Zahlen
  // ===================
  static const String steps = 'Schritte';
  static const String todaySteps = 'heutige Schritte';
  static const String noGoal = 'Kein Ziel';
  static String stepsCount(int count) => '$count Schritte';

  // ===================
  // Greetings (Time-based)
  // ===================
  static String greetingDawn(String name) => 'Guten Morgen, $name!';
  static const String greetingDawnNoName = 'Guten Morgen!';
  static String greetingDay(String name) => 'Hallo, $name!';
  static const String greetingDayNoName = 'Hallo!';
  static String greetingDusk(String name) => 'Guten Abend, $name!';
  static const String greetingDuskNoName = 'Guten Abend!';
  static String greetingNight(String name) => 'Gute Nacht, $name!';
  static const String greetingNightNoName = 'Gute Nacht!';

  // ===================
  // Auth / Sign-In
  // ===================
  static const String signIn = 'Anmelden';
  static const String signOut = 'Abmelden';
  static const String signOutConfirm = 'Möchtest du dich wirklich abmelden?';
  static const String signInWithGoogle = 'Mit Google anmelden';
  static const String signInWithApple = 'Mit Apple anmelden';
  static const String welcomeTitle = 'Willkommen bei VAGO';
  static const String welcomeSubtitle = 'Gemeinsam mehr bewegen – mit deinen Freunden.';

  // ===================
  // Onboarding
  // ===================
  static const String onboardingTitle = 'Fast geschafft 🎉';
  static const String onboardingSubtitle = 
      'Wähl dir einen eindeutigen Benutzernamen. Deine Freunde finden dich damit im Leaderboard.';
  static const String usernameLabel = 'Benutzername';
  static const String usernameHelper = 
      'Du kannst den Vorschlag anpassen. Muss eindeutig sein.';
  static const String usernameTaken = 'Dieser Benutzername ist bereits vergeben.';
  static const String usernameTooShort = 'Benutzername muss mindestens 3 Zeichen lang sein.';

  // ===================
  // Step Goal
  // ===================
  static const String stepGoalTitle = 'Schrittziel festlegen';
  static const String stepGoalSubtitle = 'Wie viele Schritte möchtest du pro Tag schaffen?';
  static const String stepGoalHelper = 'Du kannst das Ziel später jederzeit ändern.';
  static const String stepTrackingInfo = 
      'Deine Schritte werden ab jetzt gezählt. '
      'Bereits heute gelaufene Schritte vor der Installation können leider nicht erfasst werden.';

  // ===================
  // Home Screen
  // ===================
  static const String friends = 'Freunde';
  static const String groups = 'Gruppen';
  static const String challenges = 'Challenges';
  static const String stats = 'Statistik';
  static const String averageSteps = 'Ø';
  static const String leaderboard = 'Leaderboard';
  static const String noFriendsYet = 'Noch keine Freunde hinzugefügt';
  static const String addFriends = 'Freunde hinzufügen';
  static const String noGroupsYet = 'Noch keiner Gruppe beigetreten';
  static const String createOrJoinGroup = 'Gruppe erstellen oder beitreten';
  static const String pullToRefresh = 'Ziehen zum Aktualisieren';

  // ===================
  // Profil
  // ===================
  static const String profile = 'Profil';
  static const String displayName = 'Anzeigename';
  static const String displayNameRequired = 'Bitte einen Anzeigenamen eingeben.';
  static const String dailyStepGoal = 'Tägliches Schrittziel';
  static const String profileUpdated = 'Profil aktualisiert';
  static const String showOnboardingAgain = 'Einführung erneut anzeigen';

  // ===================
  // Einstellungen
  // ===================
  static const String settings = 'Einstellungen';
  static const String design = 'Design';
  static const String designLight = 'Hell';
  static const String designDark = 'Dunkel';
  static const String designSystem = 'Systemeinstellung';
  static const String designSystemSubtitle = 'Folgt den Geräteeinstellungen';
  static const String notifications = 'Benachrichtigungen';
  static const String notificationsSubtitle = 'Push-Benachrichtigungen verwalten';
  static const String emailNotifications = 'E-Mail Benachrichtigungen';
  static const String emailNotificationsSubtitle = 'E-Mail Updates verwalten';
  static const String healthData = 'Gesundheitsdaten';
  static const String healthDataSubtitle = 'Informationen zur Datenerhebung';
  static const String legal = 'Rechtliches';
  static const String legalSubtitle = 'AGB, Datenschutz & Copyright';
  static const String about = 'Über die App';
  static const String aboutSubtitle = 'Version & Informationen';
  static const String deleteAccount = 'Account löschen';
  static const String deleteAccountSubtitle = 'Alle Daten unwiderruflich löschen';
  static const String deleteAccountConfirm = 
      'Bist du sicher, dass du deinen Account löschen möchtest?\n\n'
      'Diese Aktion kann nicht rückgängig gemacht werden. '
      'Alle deine Daten werden unwiderruflich gelöscht.';
  static const String language = 'Sprache';
  static const String languageSubtitle = 'App-Sprache auswählen';
  static const String german = 'Deutsch';
  static const String english = 'Englisch';

  // ===================
  // Gesundheitsdaten Info
  // ===================
  static const String healthDataTitle = 'Datenerhebung';
  static const String healthDataInfo = 
      'VAGO erfasst deine Schrittdaten direkt über den '
      'Bewegungssensor deines Geräts. Diese Daten werden:\n\n'
      '• Lokal auf deinem Gerät gespeichert\n'
      '• Mit deinem Account synchronisiert\n'
      '• Mit deinen Freunden geteilt (nur Schrittzahlen)\n'
      '• Niemals an Dritte verkauft\n\n'
      'Du kannst deine Daten jederzeit löschen, indem du '
      'deinen Account löschst.';
  static const String permissionsTitle = 'Berechtigungen';
  static const String permissionsInfo = 
      'Die App benötigt die Berechtigung "Aktivitätserkennung" '
      'um auf den Schrittzähler-Sensor zugreifen zu können.';

  // ===================
  // Rechtliches
  // ===================
  static const String termsAndConditions = 'Allgemeine Geschäftsbedingungen';
  static const String privacyPolicy = 'Datenschutzerklärung';
  static const String copyright = 'Copyright';
  static const String copyrightText = 
      '© 2024 VAGO. Alle Rechte vorbehalten.\n\n'
      'Diese App und alle enthaltenen Inhalte sind urheberrechtlich geschützt.';
  static const String termsPlaceholder = 
      'Die AGB werden hier angezeigt sobald sie verfügbar sind.';
  static const String privacyPlaceholder = 
      'Die Datenschutzerklärung wird hier angezeigt sobald sie verfügbar ist.';

  // ===================
  // About
  // ===================
  static const String aboutTitle = 'Über VAGO';
  static const String version = 'Version 1.0.0';
  static const String aboutDescription = 
      'VAGO ist deine Step-Tracking App um mit Freunden '
      'in freundschaftlichem Wettbewerb zu treten.';
  static const String aboutFooter = 'Entwickelt mit ❤️ für mehr Bewegung im Alltag.';

  // ===================
  // Gruppen
  // ===================
  static const String createGroup = 'Gruppe erstellen';
  static const String joinGroup = 'Gruppe beitreten';
  static const String groupName = 'Gruppenname';
  static const String inviteCode = 'Einladungscode';
  static const String members = 'Mitglieder';
  static const String leaveGroup = 'Gruppe verlassen';

  // ===================
  // Freunde
  // ===================
  static const String searchFriends = 'Freunde suchen';
  static const String searchPlaceholder = 'Benutzername eingeben...';
  static const String addFriend = 'Hinzufügen';
  static const String friendAdded = 'Freund hinzugefügt!';
  static const String noResults = 'Keine Ergebnisse gefunden';
  static const String manageFriends = 'Freunde verwalten';
  static const String removeFriend = 'Freund entfernen';
  static const String friendRemoved = 'Freund entfernt';
  
  // Freundschaftsanfragen
  static const String friendRequests = 'Anfragen';
  static const String sendRequest = 'Anfragen';
  static const String requestSent = 'Anfrage gesendet!';
  static const String requestPending = 'Angefragt';
  static const String acceptRequest = 'Annehmen';
  static const String declineRequest = 'Ablehnen';
  static const String cancelRequest = 'Zurückziehen';
  static const String incomingRequests = 'Eingehende Anfragen';
  static const String outgoingRequests = 'Gesendete Anfragen';
  static const String noRequests = 'Keine Anfragen';
  static const String wantsToBeYourFriend = 'möchte dein Freund sein';
  static const String waitingForResponse = 'Warte auf Antwort...';
  static const String requestAccepted = 'Anfrage angenommen!';

  // Vorschläge
  static const String peopleYouMayKnow = 'Personen, die du vielleicht kennst';
  static String mutualFriends(int count) => 
      '$count gemeinsame${count == 1 ? 'r' : ''} Freund${count == 1 ? '' : 'e'}';

  // ===================
  // Fehlermeldungen
  // ===================
  static const String errorLoadingProfile = 'Profil konnte nicht geladen werden.';
  static const String errorSaving = 'Fehler beim Speichern.';
  static const String errorLoadingSteps = 'Fehler beim Laden der Schritte';
  static const String errorLoadingFriends = 'Fehler beim Laden deiner Freunde';
  static const String permissionDenied = 
      'Berechtigung für Aktivitätserkennung wurde nicht erteilt.';
  static const String sensorUnavailable = 
      'Schrittsensor nicht verfügbar auf diesem Gerät.';

  // ===================
  // Stats Tab
  // ===================
  static const String statsTitle = 'Deine Statistiken';
  static const String weeklyOverview = 'Wochenübersicht';
  static const String monthlyOverview = 'Monatsübersicht';
  static const String totalSteps = 'Gesamtschritte';
  static const String dailyAverage = 'Tagesdurchschnitt';

  // ===================
  // Dialoge & Bestätigungen
  // ===================
  static const String removeFriendTitle = 'Freund entfernen?';
  static String removeFriendConfirm(String name) =>
      'Möchtest du "$name" wirklich aus deiner Freundesliste entfernen?';
  static const String remove = 'Entfernen';
  static String friendWasRemoved(String name) => '$name wurde entfernt';

  // ===================
  // Sharing
  // ===================
  static String shareProfileText(String username, String link) => 
      'Lauf mit mir bei Step Buddies! 🏃‍♂️\nFüge $username als Freund hinzu: $link';
      
  static String shareGroupText(String groupName, String link) => 
      'Komm in meine Laufgruppe "$groupName"! 🏆\nTritt hier bei: $link';

  // ===================
  // Zusätzliche Fehlermeldungen
  // ===================
  static const String searchFailed = 'Suche fehlgeschlagen. Bitte später erneut versuchen.';
  static const String searchHint = 'Gib mindestens 2 Zeichen ein, um Freunde zu finden.';
  static const String unknownError = 'Es ist ein unerwarteter Fehler aufgetreten.';
  static const String errorLoadingData = 'Daten konnten nicht geladen werden.';
  static const String noLoggedInUser = 'Kein angemeldeter Benutzer.';
  static const String errorLoadingGroups = 'Fehler beim Laden der Gruppen';

  // ===================
  // Challenges
  // ===================
  static const String activeChallenges = 'Laufende Challenges';
  static const String pendingChallenges = 'Geplant';
  static const String completedChallenges = 'Beendet';
  static const String createChallenge = 'Challenge erstellen';
  static const String challengeTitleLabel = 'Titel der Challenge';
  static const String challengeDurationLabel = 'Dauer (Tage)';
  static const String challengeStartLabel = 'Startdatum';
  static const String selectParticipants = 'Teilnehmer auswählen';
  static const String createTeams = 'Teams erstellen';
  static const String shuffleTeams = 'Teams mischen';
  static const String addTeam = 'Team hinzufügen';
  static const String challengeCreated = 'Challenge erstellt!';
  static const String challengeStatus = 'Status';
  static const String remainingTime = 'Verbleibende Zeit';
  static const String adminControls = 'Admin Steuerung';
  static const String deleteChallenge = 'Challenge löschen';
  static const String saveTeams = 'Teams speichern';
  static const String noChallenges = 'Keine Challenges vorhanden.';
  static const String startChallenge = 'Starte deine erste Challenge!';
  static const String errorCreatingGroup = 'Fehler beim Erstellen der Gruppe';
  static const String errorLoadingUserData = 'Fehler beim Laden der Benutzerdaten';
  
  static const String challengeDetails = 'Details';
  static const String challengeTeams = 'Teams';
  static const String challengeStart = 'Start:';
  static const String challengeEndedAt = 'Beendet am';
  static String daysLeft(int days) => 'Noch $days Tage';
  static String challengeSteps(int steps) => '$steps Schritte';

  // Vergleich
  static const String comparison = 'Vergleich';
  static const String statsComparison = 'Stats im Vergleich';
  static const String metric = 'Metrik';
  static const String stepsToday = 'Schritte heute';
  static const String stepsYesterday = 'Schritte gestern';
  static const String last7Days = 'Letzte 7 Tage';
  static const String bestDay = 'Bester Tag';
  static const String bestWeek = 'Beste Woche';
  static const String you = 'Du';
  static const String unknown = 'Unbekannt';
}
