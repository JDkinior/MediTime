// lib/notifiers/profile_notifier.dart
import 'package:flutter/material.dart';

/// Enum representing the different states of the profile
enum ProfileStatus { initial, loading, loaded, error }

/// Immutable state class for profile data
@immutable
class ProfileState {
  final String? userName;
  final String? profileImageUrl;
  final ProfileStatus status;
  final String? errorMessage;

  const ProfileState({
    this.userName,
    this.profileImageUrl,
    this.status = ProfileStatus.initial,
    this.errorMessage,
  });

  /// Creates an initial empty state
  const ProfileState.initial() : this();

  /// Creates a loading state
  const ProfileState.loading() : this(status: ProfileStatus.loading);

  /// Creates a loaded state with data
  const ProfileState.loaded({
    required String? userName,
    required String? profileImageUrl,
  }) : this(
          userName: userName,
          profileImageUrl: profileImageUrl,
          status: ProfileStatus.loaded,
        );

  /// Creates an error state
  const ProfileState.error(String errorMessage)
      : this(
          status: ProfileStatus.error,
          errorMessage: errorMessage,
        );

  /// Creates a copy of this state with updated values
  ProfileState copyWith({
    String? userName,
    String? profileImageUrl,
    ProfileStatus? status,
    String? errorMessage,
  }) {
    return ProfileState(
      userName: userName ?? this.userName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileState &&
          runtimeType == other.runtimeType &&
          userName == other.userName &&
          profileImageUrl == other.profileImageUrl &&
          status == other.status &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      userName.hashCode ^
      profileImageUrl.hashCode ^
      status.hashCode ^
      errorMessage.hashCode;

  @override
  String toString() {
    return 'ProfileState{userName: $userName, profileImageUrl: $profileImageUrl, status: $status, errorMessage: $errorMessage}';
  }
}

/// Enhanced `ChangeNotifier` for managing global user profile state.
///
/// Now includes proper state management with loading, error, and success states.
/// Allows widgets like `CustomDrawer` or profile headers to update automatically
/// when user name or image changes, without passing data through multiple widgets.
class ProfileNotifier extends ChangeNotifier {
  ProfileState _state = const ProfileState.initial();

  /// Current profile state
  ProfileState get state => _state;

  /// Convenience getters for backward compatibility
  String? get userName => _state.userName;
  String? get profileImageUrl => _state.profileImageUrl;
  ProfileStatus get status => _state.status;
  String? get errorMessage => _state.errorMessage;

  /// Sets the profile to loading state
  void setLoading() {
    _updateState(const ProfileState.loading());
  }

  /// Updates the profile data and sets to loaded state
  ///
  /// Only notifies if there's actually a change in the data to avoid
  /// unnecessary UI rebuilds.
  void updateProfile({String? newName, String? newImageUrl}) {
    final newState = ProfileState.loaded(
      userName: newName ?? _state.userName,
      profileImageUrl: newImageUrl ?? _state.profileImageUrl,
    );

    if (_state != newState) {
      _updateState(newState);
    }
  }

  /// Sets an error state with the given error message
  void setError(String error) {
    _updateState(ProfileState.error(error));
  }

  /// Clears the profile data, typically when signing out
  void clearProfile() {
    _updateState(const ProfileState.initial());
  }

  /// Internal method to update state and notify listeners
  void _updateState(ProfileState newState) {
    _state = newState;
    notifyListeners();
  }
}