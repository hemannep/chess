import 'package:just_audio/just_audio.dart';

class SoundService {
  final _player = AudioPlayer();
  bool _enabled = true;

  void setEnabled(bool val) => _enabled = val;

  Future<void> _play(String asset) async {
    if (!_enabled) return;
    try {
      await _player.setAsset('assets/sounds/$asset');
      await _player.play();
    } catch (_) {
      // Silently fail if asset missing — don't crash gameplay
    }
  }

  void playMove() => _play('move.mp3');
  void playCapture() => _play('capture.mp3');
  void playCheck() => _play('check.mp3');
  void playGameOver() => _play('game_over.mp3');
  void playCastle() => _play('castle.mp3');
  void playPromotion() => _play('promotion.mp3');

  void dispose() => _player.dispose();
}
