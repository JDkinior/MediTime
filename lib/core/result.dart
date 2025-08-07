// lib/core/result.dart

/// A generic Result class for consistent error handling across the application.
///
/// This class encapsulates the result of an operation that can either succeed or fail,
/// providing a type-safe way to handle errors without throwing exceptions.
sealed class Result<T> {
  const Result();

  /// Creates a successful result with data
  const factory Result.success(T data) = Success<T>;

  /// Creates a failed result with an error message
  const factory Result.failure(String error) = Failure<T>;

  /// Returns true if the result is successful
  bool get isSuccess => this is Success<T>;

  /// Returns true if the result is a failure
  bool get isFailure => this is Failure<T>;

  /// Returns the data if successful, null otherwise
  T? get data => switch (this) {
    Success<T>(data: final data) => data,
    Failure<T>() => null,
  };

  /// Returns the error message if failed, null otherwise
  String? get error => switch (this) {
    Success<T>() => null,
    Failure<T>(error: final error) => error,
  };

  /// Transforms the data if successful, otherwise returns a failure with the same error
  Result<U> map<U>(U Function(T data) transform) {
    return switch (this) {
      Success<T>(data: final data) => Result.success(transform(data)),
      Failure<T>(error: final error) => Result.failure(error),
    };
  }

  /// Executes the appropriate callback based on the result
  R when<R>({
    required R Function(T data) success,
    required R Function(String error) failure,
  }) {
    return switch (this) {
      Success<T>(data: final data) => success(data),
      Failure<T>(error: final error) => failure(error),
    };
  }
}

/// Represents a successful result
final class Success<T> extends Result<T> {
  const Success(this.data);
  
  @override
  final T data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> &&
          runtimeType == other.runtimeType &&
          data == other.data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Success(data: $data)';
}

/// Represents a failed result
final class Failure<T> extends Result<T> {
  const Failure(this.error);
  
  @override
  final String error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Failure(error: $error)';
}
