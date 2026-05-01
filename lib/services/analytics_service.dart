import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  Future<void> setUserId(String uid) async {
    await _analytics.setUserId(id: uid);
    await _crashlytics.setUserIdentifier(uid);
  }

  Future<void> logScreenView(String screenName) =>
      _analytics.logScreenView(screenName: screenName);

  Future<void> logMoveSubmitted(String gameId, String from, String to) =>
      _analytics.logEvent(name: 'move_submitted', parameters: {
        'game_id': gameId,
        'from': from,
        'to': to,
      });

  Future<void> logGameCompleted(String gameId, String result) =>
      _analytics.logEvent(name: 'game_completed', parameters: {
        'game_id': gameId,
        'result': result,
      });

  Future<void> logGameStarted(String mode, String timeControl) =>
      _analytics.logEvent(name: 'game_started', parameters: {
        'mode': mode,
        'time_control': timeControl,
      });

  Future<void> logError(String type, String message) {
    _crashlytics.log('$type: $message');
    return _analytics.logEvent(name: 'app_error', parameters: {
      'error_type': type,
      'message': message,
    });
  }

  Future<void> logAchievementUnlocked(String achievementId) =>
      _analytics.logEvent(
        name: 'achievement_unlocked',
        parameters: {'achievement_id': achievementId},
      );
}
