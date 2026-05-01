import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chess_master/features/game/domain/entities/game_entity.dart';

class ProfileRepository {
  final FirebaseFirestore _db;
  // ignore: unused_field
  final FirebaseAuth _auth;

  ProfileRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _db = firestore,
        _auth = auth;

  Stream<UserEntity?> watchUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserEntity.fromMap(snap.data()!);
    });
  }

  Future<UserEntity?> getUser(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    return UserEntity.fromMap(snap.data()!);
  }

  Future<void> updateSettings(String uid, UserSettings settings) async {
    await _db.collection('users').doc(uid).update({'settings': settings.toMap()});
  }

  Future<void> updateProfile(String uid,
      {String? username, String? avatarUrl, String? country}) async {
    final updates = <String, dynamic>{};
    if (username != null) updates['username'] = username;
    if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;
    if (country != null) updates['country'] = country;
    if (updates.isNotEmpty) await _db.collection('users').doc(uid).update(updates);
  }

  Future<bool> isUsernameAvailable(String username) async {
    final snap = await _db
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return snap.docs.isEmpty;
  }

  Future<int> updateStreak(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return 0;
    final user = UserEntity.fromMap(snap.data()!);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastActive = user.lastActiveDate != null
        ? DateTime(user.lastActiveDate!.year, user.lastActiveDate!.month,
            user.lastActiveDate!.day)
        : null;

    int newStreak = user.streak;
    if (lastActive == null ||
        lastActive.isBefore(today.subtract(const Duration(days: 1)))) {
      newStreak = 1;
    } else if (lastActive == today.subtract(const Duration(days: 1))) {
      newStreak = user.streak + 1;
    }

    await _db.collection('users').doc(uid).update({
      'streak': newStreak,
      'lastActiveDate': today.toIso8601String(),
    });
    return newStreak;
  }

  Future<List<UserEntity>> getLeaderboard({int limit = 50}) async {
    final snap = await _db
        .collection('users')
        .orderBy('rating', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => UserEntity.fromMap(d.data())).toList();
  }
}
