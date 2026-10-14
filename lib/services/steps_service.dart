import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ergebnis des Step-Tracking mit Statusinfo
class StepResult {
  final int steps;
  final StepStatus status;
  final String? errorMessage;

  StepResult({
    required this.steps,
    required this.status,
    this.errorMessage,
  });

  bool get isSuccess => status == StepStatus.success;
}

enum StepStatus {
  success,
  permissionDenied,
  sensorUnavailable,
  error,
}

class StepsService {
  static const String _keyLastDate = 'steps_last_date';
  static const String _keyStepsAtDayStart = 'steps_at_day_start';
  static const String _keyLastKnownSteps = 'steps_last_known';

  /// Holt die heutigen Schritte (seit Mitternacht) mit Status-Info
  Future<StepResult> getTodayStepsWithStatus() async {
    // 1. Permission prüfen
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      debugPrint('[StepsService] ACTIVITY_RECOGNITION nicht erlaubt');
      return StepResult(
        steps: 0,
        status: StepStatus.permissionDenied,
        errorMessage: 'Berechtigung für Aktivitätserkennung wurde nicht erteilt.',
      );
    }

    // 2. Aktuellen Sensor-Wert lesen (seit letztem Boot)
    final sensorResult = await _readStepCountFromSensor();
    
    if (sensorResult == null) {
      return StepResult(
        steps: 0,
        status: StepStatus.sensorUnavailable,
        errorMessage: 'Schrittsensor nicht verfügbar auf diesem Gerät.',
      );
    }
    
    final totalStepsSinceBoot = sensorResult;
    debugPrint('[StepsService] Steps seit Boot: $totalStepsSinceBoot');

    // 3. Tages-Berechnung
    final prefs = await SharedPreferences.getInstance();
    final todayStr = _todayDateString();
    final lastDate = prefs.getString(_keyLastDate);
    final lastKnownSteps = prefs.getInt(_keyLastKnownSteps) ?? 0;

    // Ersten Lauf erkennen (noch nie gespeichert)
    final isFirstRun = lastDate == null;
    
    // Neuen Tag erkennen
    final isNewDay = lastDate != null && lastDate != todayStr;
    
    // Phone-Neustart erkennen (aktuelle Steps < zuletzt bekannte Steps)
    final wasPhoneRebooted = totalStepsSinceBoot < lastKnownSteps;

    if (isFirstRun || isNewDay || wasPhoneRebooted) {
      // Neuer Startpunkt: ab JETZT zählen wir
      debugPrint('[StepsService] Setze neuen Referenzpunkt. Grund: firstRun=$isFirstRun, newDay=$isNewDay, reboot=$wasPhoneRebooted');
      await prefs.setString(_keyLastDate, todayStr);
      await prefs.setInt(_keyStepsAtDayStart, totalStepsSinceBoot);
      await prefs.setInt(_keyLastKnownSteps, totalStepsSinceBoot);
      
      return StepResult(steps: 0, status: StepStatus.success);
    }

    // Gleicher Tag, kein Neustart → Differenz berechnen
    final stepsAtDayStart = prefs.getInt(_keyStepsAtDayStart) ?? totalStepsSinceBoot;
    final todaySteps = totalStepsSinceBoot - stepsAtDayStart;

    // Letzten bekannten Wert speichern (für Reboot-Erkennung)
    await prefs.setInt(_keyLastKnownSteps, totalStepsSinceBoot);

    debugPrint('[StepsService] Heutige Schritte: $todaySteps (start=$stepsAtDayStart, now=$totalStepsSinceBoot)');
    return StepResult(
      steps: todaySteps > 0 ? todaySteps : 0,
      status: StepStatus.success,
    );
  }

  /// Legacy-Methode für Abwärtskompatibilität
  Future<int> getTodaySteps() async {
    final result = await getTodayStepsWithStatus();
    return result.steps;
  }

  /// Liest den Step-Count direkt vom Sensor (blockierend mit Timeout)
  /// Gibt null zurück wenn Sensor nicht verfügbar
  Future<int?> _readStepCountFromSensor() async {
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
          debugPrint('[StepsService] Sensor-Fehler: $error');
          completer.complete(null); // null = Sensor nicht verfügbar
        }
      },
    );

    // Timeout nach 10 Sekunden
    Future.delayed(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        sub.cancel();
        debugPrint('[StepsService] Timeout beim Lesen des Sensors');
        completer.complete(null);
      }
    });

    return completer.future;
  }

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Stream für Live-Updates (optional, für spätere Nutzung)
  Stream<int> get stepCountStream async* {
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      yield 0;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    var currentDateStr = _todayDateString();
    var stepsAtDayStart = prefs.getInt(_keyStepsAtDayStart) ?? 0;

    await for (final event in Pedometer.stepCountStream) {
      final nowDateStr = _todayDateString();

      if (nowDateStr != currentDateStr) {
        // Mitternacht überschritten → neu initialisieren
        currentDateStr = nowDateStr;
        stepsAtDayStart = event.steps;
        await prefs.setString(_keyLastDate, currentDateStr);
        await prefs.setInt(_keyStepsAtDayStart, stepsAtDayStart);
        yield 0;
      } else {
        var todaySteps = event.steps - stepsAtDayStart;
        if (todaySteps < 0) {
          // Phone restart
          stepsAtDayStart = event.steps;
          await prefs.setInt(_keyStepsAtDayStart, stepsAtDayStart);
          todaySteps = 0;
        }
        yield todaySteps;
      }
    }
  }
}
