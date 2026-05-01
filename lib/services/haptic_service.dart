import 'package:flutter/services.dart';

/// Uses Flutter's built-in HapticFeedback — no native plugin dependency.
class HapticService {
  bool _enabled = true;

  void setEnabled(bool val) => _enabled = val;

  void selection() {
    if (_enabled) HapticFeedback.selectionClick();
  }

  void impact() {
    if (_enabled) HapticFeedback.lightImpact();
  }

  void heavyImpact() {
    if (_enabled) HapticFeedback.heavyImpact();
  }

  void error() {
    if (_enabled) HapticFeedback.vibrate();
  }

  void notification() {
    if (_enabled) HapticFeedback.mediumImpact();
  }
}
