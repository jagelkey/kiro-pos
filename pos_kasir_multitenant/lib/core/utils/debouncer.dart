import 'dart:async';
import 'package:flutter/foundation.dart';

/// Debouncer utility for search and other frequent operations
/// Delays execution until user stops typing
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  /// Call the action after delay
  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Run async action after delay
  void run(Future<void> Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, () async {
      await action();
    });
  }

  /// Cancel pending action
  void cancel() {
    _timer?.cancel();
  }

  /// Dispose and cancel timer
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  /// Check if timer is active
  bool get isActive => _timer?.isActive ?? false;
}

/// Throttler utility for rate limiting
/// Ensures action is called at most once per interval
class Throttler {
  final Duration interval;
  DateTime? _lastCall;

  Throttler({this.interval = const Duration(milliseconds: 500)});

  /// Call action if enough time has passed since last call
  void call(VoidCallback action) {
    final now = DateTime.now();

    if (_lastCall == null || now.difference(_lastCall!) >= interval) {
      _lastCall = now;
      action();
    }
  }

  /// Run async action if enough time has passed
  Future<void> run(Future<void> Function() action) async {
    final now = DateTime.now();

    if (_lastCall == null || now.difference(_lastCall!) >= interval) {
      _lastCall = now;
      await action();
    }
  }

  /// Reset throttler
  void reset() {
    _lastCall = null;
  }
}
