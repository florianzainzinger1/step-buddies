import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// Name des periodischen Background-Tasks
const String backgroundSyncTaskName = 'stepBuddiesBackgroundSync';

/// Top-Level Callback für Workmanager (muss außerhalb jeder Klasse sein)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('[BackgroundSync] Task gestartet: $taskName');
    
    try {
      // Firebase initialisieren (notwendig im Background-Isolate)
      await Firebase.initializeApp();
      
      // User ID aus SharedPreferences holen (wurde beim Login gespeichert)
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('background_sync_user_id');
      
      if (userId == null || userId.isEmpty) {
        debugPrint('[BackgroundSync] Kein User eingeloggt, überspringe Sync');
        return true;
      }
      
      // Schritte vom Sensor lesen
      final steps = await _readStepsFromSensor();
      if (steps == null) {
        debugPrint('[BackgroundSync] Sensor nicht verfügbar');
        return true;
      }
      
      // Tagesberechnung (gleiche Logik wie StepsService)
      final todaySteps = await _calculateTodaySteps(steps, prefs);
      
      if (todaySteps >= 0) {
        // In Firestore speichern
        await _saveDailySteps(userId, todaySteps);
        debugPrint('[BackgroundSync] Gespeichert: $todaySteps Schritte für User $userId');
      }
      
      return true;
    } catch (e, st) {
      debugPrint('[BackgroundSync] Fehler: $e');
      debugPrint('$st');
      return false;
    }
  });
}

/// Liest Schritte vom Pedometer-Sensor
Future<int?> _readStepsFromSensor() async {
  final completer = Completer<int?>();
  
  late StreamSubscription<StepCount> sub;
  sub = Pedometer.stepCountStream.listen(
    (event) {
      if (!completer.isCompleted) {
        sub.cancel();
        completer.complete(event.steps);
      }
    },
    onError: (error) {
      if (!completer.isCompleted) {
        sub.cancel();
        completer.complete(null);
      }
    },
  );

  // Timeout nach 5 Sekunden
  Future.delayed(const Duration(seconds: 5), () {
    if (!completer.isCompleted) {
      sub.cancel();
      completer.complete(null);
    }
  });

  return completer.future;
}

/// Berechnet die heutigen Schritte basierend auf dem Sensor-Wert
Future<int> _calculateTodaySteps(int totalStepsSinceBoot, SharedPreferences prefs) async {
  const keyLastDate = 'steps_last_date';
  const keyStepsAtDayStart = 'steps_at_day_start';
  const keyLastKnownSteps = 'steps_last_known';
  
  final now = DateTime.now();
  final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  
  final lastDate = prefs.getString(keyLastDate);
  final lastKnownSteps = prefs.getInt(keyLastKnownSteps) ?? 0;
  
  final isFirstRun = lastDate == null;
  final isNewDay = lastDate != null && lastDate != todayStr;
  final wasPhoneRebooted = totalStepsSinceBoot < lastKnownSteps;

  if (isFirstRun || isNewDay || wasPhoneRebooted) {
    debugPrint('[BackgroundSync] Neuer Referenzpunkt: firstRun=$isFirstRun, newDay=$isNewDay, reboot=$wasPhoneRebooted');
    await prefs.setString(keyLastDate, todayStr);
    await prefs.setInt(keyStepsAtDayStart, totalStepsSinceBoot);
    await prefs.setInt(keyLastKnownSteps, totalStepsSinceBoot);
    return 0;
  }

  final stepsAtDayStart = prefs.getInt(keyStepsAtDayStart) ?? totalStepsSinceBoot;
  final todaySteps = totalStepsSinceBoot - stepsAtDayStart;

  await prefs.setInt(keyLastKnownSteps, totalStepsSinceBoot);

  return todaySteps > 0 ? todaySteps : 0;
}

/// Speichert die Schritte in Firestore
Future<void> _saveDailySteps(String userId, int steps) async {
  final now = DateTime.now();
  final dateStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final docId = '${userId}_$dateStr';

  await FirebaseFirestore.instance.collection('dailySteps').doc(docId).set({
    'userId': userId,
    'date': DateTime(now.year, now.month, now.day),
    'steps': steps,
    'updatedAt': FieldValue.serverTimestamp(),
    'source': 'background_sync',
  }, SetOptions(merge: true));
}

/// Service-Klasse für die Initialisierung
class BackgroundSyncService {
  BackgroundSyncService._();
  static final instance = BackgroundSyncService._();
  
  bool _isInitialized = false;

  /// Initialisiert den Background-Sync (einmal beim App-Start aufrufen)
  Future<void> initialize(String userId) async {
    if (_isInitialized) return;
    
    // User ID für Background-Task speichern
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('background_sync_user_id', userId);
    
    // Workmanager initialisieren
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    
    // Periodischen Task registrieren (alle 15 Minuten - Android Minimum)
    await Workmanager().registerPeriodicTask(
      backgroundSyncTaskName,
      backgroundSyncTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected, // Nur bei Netzwerk
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep, // Bestehenden Task behalten
    );
    
    _isInitialized = true;
    debugPrint('[BackgroundSync] Initialisiert für User: $userId');
  }
  
  /// Stoppt den Background-Sync (z.B. beim Logout)
  Future<void> stop() async {
    await Workmanager().cancelByUniqueName(backgroundSyncTaskName);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('background_sync_user_id');
    
    _isInitialized = false;
    debugPrint('[BackgroundSync] Gestoppt');
  }
}
