// lib/core/stream_cache.dart
import 'dart:async';

/// A generic stream cache that prevents duplicate stream subscriptions
/// and improves performance by reusing existing streams.
/// 
/// This is particularly useful for Firestore streams that might be
/// accessed from multiple widgets simultaneously.
class StreamCache<K, T> {
  final Map<K, StreamController<T>> _controllers = {};
  final Map<K, StreamSubscription<T>> _subscriptions = {};
  final Map<K, T?> _lastValues = {};

  /// Gets or creates a cached stream for the given key.
  /// 
  /// If a stream already exists for this key, returns a stream that replays
  /// the latest value only to the new subscriber without re-emitting to
  /// existing listeners.
  Stream<T> getStream(K key, Stream<T> Function() streamFactory) {
    if (!_controllers.containsKey(key)) {
      final controller = StreamController<T>.broadcast(
        onCancel: () => _cleanup(key),
      );

      _controllers[key] = controller;

      final subscription = streamFactory().listen(
        (data) {
          _lastValues[key] = data;
          if (!controller.isClosed) {
            controller.add(data);
          }
        },
        onError: (error) {
          if (!controller.isClosed) {
            controller.addError(error);
          }
          _cleanup(key);
        },
        onDone: () {
          if (!controller.isClosed) {
            controller.close();
          }
          _cleanup(key);
        },
      );

      _subscriptions[key] = subscription;
    }

    final controller = _controllers[key]!;

    return Stream<T>.multi((multiController) {
      if (_lastValues.containsKey(key) && _lastValues[key] != null) {
        multiController.add(_lastValues[key] as T);
      }
      final sub = controller.stream.listen(
        multiController.add,
        onError: multiController.addError,
        onDone: multiController.close,
      );
      multiController.onCancel = () => sub.cancel();
    }, isBroadcast: true);
  }

  /// Clears the cache for a specific key
  void clearKey(K key) {
    _cleanup(key);
  }

  /// Clears all cached streams
  void clearAll() {
    final keys = List<K>.from(_controllers.keys);
    for (final key in keys) {
      _cleanup(key);
    }
  }

  /// Internal cleanup method
  void _cleanup(K key) {
    _subscriptions[key]?.cancel();
    _subscriptions.remove(key);
    
    final controller = _controllers[key];
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
    _controllers.remove(key);
    _lastValues.remove(key);
  }

  /// Disposes all resources
  void dispose() {
    clearAll();
  }

  /// Gets the number of cached streams
  int get cacheSize => _controllers.length;

  /// Checks if a key is cached
  bool containsKey(K key) => _controllers.containsKey(key);

  /// Gets the last cached value for a key (if any)
  T? getLastValue(K key) => _lastValues[key];
}
