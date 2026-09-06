import 'dart:async';

/// Delays used by the battle presentation, independently of the duel rules.
///
/// Pausing preserves the remaining duration of each task, including AI pacing.
/// Callers awaiting [wait] must stop their work when it returns false: the
/// screen was disposed or the current presentation was cancelled/restarted.
final class BattlePresentationScheduler {
  BattlePresentationScheduler({Duration Function()? elapsed}) {
    _stopwatch.start();
    _elapsed = elapsed ?? (() => _stopwatch.elapsed);
  }

  final Stopwatch _stopwatch = Stopwatch();
  late final Duration Function() _elapsed;
  final Set<BattlePresentationTask> _tasks = {};
  bool _paused = false;
  bool _disposed = false;

  bool get isPaused => _paused;
  bool get isDisposed => _disposed;

  BattlePresentationTask schedule(Duration duration, void Function() callback) {
    return _createTask(duration, callback: callback);
  }

  Future<bool> wait(Duration duration) {
    final completion = Completer<bool>();
    _createTask(duration, completion: completion);
    return completion.future;
  }

  BattlePresentationTask _createTask(
    Duration duration, {
    void Function()? callback,
    Completer<bool>? completion,
  }) {
    final task = BattlePresentationTask._(
      this,
      duration.isNegative ? Duration.zero : duration,
      callback,
      completion,
    );
    if (_disposed) {
      task.cancel();
    } else {
      _tasks.add(task);
      if (!_paused) task._start();
    }
    return task;
  }

  void pause() {
    if (_disposed || _paused) return;
    _paused = true;
    for (final task in _tasks) {
      task._pause();
    }
  }

  void resume() {
    if (_disposed || !_paused) return;
    _paused = false;
    for (final task in _tasks) {
      task._start();
    }
  }

  /// Cancels all pending callbacks and completes pending waits with false.
  /// The pause state is preserved so a restart can explicitly resume when ready.
  void cancelAll() {
    for (final task in _tasks.toList()) {
      task.cancel();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancelAll();
    _stopwatch.stop();
  }
}

final class BattlePresentationTask {
  BattlePresentationTask._(
    this._scheduler,
    this._remaining,
    this._callback,
    this._completion,
  );

  final BattlePresentationScheduler _scheduler;
  final void Function()? _callback;
  final Completer<bool>? _completion;
  Duration _remaining;
  Duration? _startedAt;
  Timer? _timer;
  bool _active = true;

  bool get isActive => _active;

  void _start() {
    if (!_active) return;
    _startedAt = _scheduler._elapsed();
    _timer = Timer(_remaining, _finish);
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    final startedAt = _startedAt;
    if (startedAt != null) {
      final remainder = _remaining - (_scheduler._elapsed() - startedAt);
      _remaining = remainder.isNegative ? Duration.zero : remainder;
      _startedAt = null;
    }
  }

  void _finish() {
    if (!_active) return;
    _active = false;
    _timer = null;
    _scheduler._tasks.remove(this);
    _completion?.complete(true);
    _callback?.call();
  }

  void cancel() {
    if (!_active) return;
    _active = false;
    _timer?.cancel();
    _timer = null;
    _scheduler._tasks.remove(this);
    _completion?.complete(false);
  }
}
