import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityService {
  final _connectivity = Connectivity();

  /// Defensive — works with both List and single value APIs across
  /// connectivity_plus versions.
  Stream<bool> get onlineStream {
    return _connectivity.onConnectivityChanged.map((result) {
      if (result is List) {
        return (result as List).any((r) => r != ConnectivityResult.none);
      }
      return result != ConnectivityResult.none;
    });
  }

  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    if (result is List) {
      return (result as List).any((r) => r != ConnectivityResult.none);
    }
    return result != ConnectivityResult.none;
  }
}

final connectivityServiceProvider = Provider((_) => ConnectivityService());

final connectivityProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).onlineStream;
});
