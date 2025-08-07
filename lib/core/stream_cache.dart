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
  /// If a stream already exists for this key, returns the existing stream.
  /// Otherwise, creates a new stream using the provided factory function.
  Stream<T> getStream(K key, Stream<T> Function() streamFactory) {
    // If we already have a controller for this key, return its stream
    if (_controllers.containsKey(key)) {
      final controller = _controllers[key]!;
      
      // If we have a cached value, emit it immediately
      if (_lastValues.containsKey(key) && _lastValues[key] != null) {
        // Schedule the emission for the next event loop to avoid sync issues
        scheduleMicrotask(() {
          if (!controller.isClosed) {
            controller.add(_lastValues[key] as T);
          }
        });
      }
      
      return controller.stream;
    }

    // Create a new controller and subscription
    final controller = StreamController<T>.broadcast(
      onCancel: () => _cleanup(key),
    );
    
    _controllers[key] = controller;

    // Subscribe to the original stream
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
      },
      onDone: () {
        if (!controller.isClosed) {
          controller.close();
        }
        _cleanup(key);
      },
    );

    _subscriptions[key] = subscription;

    return controller.stream;
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