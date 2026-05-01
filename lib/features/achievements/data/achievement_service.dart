import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chess_master/features/game/domain/entities/game_entity.dart';
import 'package:chess_master/services/analytics_service.dart';

class AchievementService {
  final FirebaseFirestore _db;
  final AnalyticsService _analytics;

  AchievementService({FirebaseFirestore? db, AnalyticsService? analytics})
      : _db = db ?? FirebaseFirestore.instance,
        _analytics = analytics ?? AnalyticsService();

  Future<List<Achievement>> checkGameAchievements({
    required String uid,
    required UserEntity user,
    required GameEntity game,
    required bool won,
  }) async {
    final unlocked = <Achievement>[];
    final checks = <String, bool Function()>{
      'first_win': () => won && user.wins == 0,
      'ten_wins': () => won && user.wins == 9,
      'online_first': () =>
          game.mode == GameMode.online && user.gamesPlayed == 0,
      'vs_hard_bot': () =>
          won &&
          game.mode == GameMode.bot &&
          (game.botDifficulty == BotDifficulty.hard ||
              game.botDifficulty == BotDifficulty.expert),
      'rating_1400': () =>
          user.rating >= 1400 && (user.rating - (won ? 20 : -20)) < 1400,
    };
    for (final entry in checks.entries) {
      if (user.earnedAchievements.contains(entry.key)) continue;
      if (!entry.value()) continue;
      final achievement = Achievements.findById(entry.key);
      if (achievement == null) continue;
      try {
        await _db.collection('users').doc(uid).update({
          'earnedAchievements': FieldValue.arrayUnion([entry.key]),
          'xp': FieldValue.increment(achievement.xpReward),
        });
        await _analytics.logAchievementUnlocked(entry.key);
        unlocked.add(achievement);
      } catch (_) {}
    }
    return unlocked;
  }
}
