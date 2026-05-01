import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chess_master/features/game/domain/entities/game_entity.dart';
import 'package:chess_master/services/analytics_service.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final AnalyticsService _analytics;

  AuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore db,
    required AnalyticsService analytics,
  })  : _auth = auth,
        _db = db,
        _analytics = analytics;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User> signInAsGuest() async {
    final cred = await _auth.signInAnonymously();
    final user = cred.user!;
    await _ensureUserDocument(user, isGuest: true);
    await _analytics.setUserId(user.uid);
    return user;
  }

  Future<User?> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    return cred.user;
  }

  Future<User?> registerWithEmail(
      String email, String password, String username) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    final user = cred.user!;
    await _ensureUserDocument(user, isGuest: false, displayName: username);
    return user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> _ensureUserDocument(User user,
      {required bool isGuest, String? displayName}) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;

    final username = displayName ?? _generateGuestName();
    await ref.set(UserEntity(
      uid: user.uid,
      username: username,
      email: user.email,
      avatarUrl: user.photoURL,
      isGuest: isGuest,
    ).toMap());
  }

  String _generateGuestName() {
    const adjectives = ['Swift', 'Bold', 'Clever', 'Fierce', 'Calm'];
    const nouns = ['Knight', 'Bishop', 'Rook', 'King', 'Pawn'];
    final n = DateTime.now().millisecond;
    return '${adjectives[n % adjectives.length]}'
        '${nouns[n % nouns.length]}'
        '${100 + n % 900}';
  }
}
