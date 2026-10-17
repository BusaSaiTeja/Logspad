import 'dart:async';
import 'package:flutter/foundation.dart';

/// General debounce utility for delayable operations such as search inputs and auto-saving.
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 400)});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  bool get isActive => _timer?.isActive ?? false;
}

/// Throttler / Tap-debouncer to prevent duplicate button taps and rapid double-submissions.
class TapDebouncer {
  final Duration cooldown;
  DateTime? _lastTapTime;

  TapDebouncer({this.cooldown = const Duration(milliseconds: 600)});

  /// Runs the callback only if cooldown has elapsed since the last execution.
  bool run(VoidCallback action) {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!) < cooldown) {
      return false; // Ignored duplicate tap
    }
    _lastTapTime = now;
    action();
    return true;
  }

  /// Wraps any [VoidCallback] with rapid double-tap protection.
  VoidCallback wrap(VoidCallback callback) {
    return () => run(callback);
  }
}

/// Global helper for instant double-tap protection across buttons and navigation calls.
class SafeTap {
  static DateTime? _lastGlobalTap;

  /// Runs [action] only if at least [cooldown] has elapsed since the last safe tap.
  static void run(VoidCallback action, {Duration cooldown = const Duration(milliseconds: 500)}) {
    final now = DateTime.now();
    if (_lastGlobalTap != null && now.difference(_lastGlobalTap!) < cooldown) {
      return;
    }
    _lastGlobalTap = now;
    action();
  }

  /// Returns a throttled version of [callback].
  static VoidCallback wrap(VoidCallback callback, {Duration cooldown = const Duration(milliseconds: 500)}) {
    return () => run(callback, cooldown: cooldown);
  }
}
