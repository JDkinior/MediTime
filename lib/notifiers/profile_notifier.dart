// lib/notifiers/profile_notifier.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/services/profile_cache_service.dart';

/// Enum representing the different states of the profile
enum ProfileStatus { initial, loading, loaded, error }

/// Immutable state class for profile data
@immutable
class ProfileState {
  final String? userName;
  final String? profileImageUrl;
  final String? localImagePath;
  final ProfileStatus status;
  final String? errorMessage;

  const ProfileState({
    this.userName,
    this.profileImageUrl,
    this.localImagePath,
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
    String? localImagePath,
  }) : this(
          userName: userName,
          profileImageUrl: profileImageUrl,
          localImagePath: localImagePath,
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
    String? localImagePath,
    ProfileStatus? status,
    String? errorMessage,
  }) {
    return ProfileState(
      userName: userName ?? this.userName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      localImagePath: localImagePath ?? this.localImagePath,
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
          localImagePath == other.localImagePath &&
          status == other.status &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      userName.hashCode ^
      profileImageUrl.hashCode ^
      (localImagePath?.hashCode ?? 0) ^
      status.hashCode ^
      errorMessage.hashCode;

  @override
  String toString() {
    return 'ProfileState{userName: $userName, profileImageUrl: $profileImageUrl, localImagePath: $localImagePath, status: $status, errorMessage: $errorMessage}';
  }
}

/// Enhanced `ChangeNotifier` for managing global user profile state.
///
/// Includes proper state management with loading, error, success states and
/// instant local disk cache recovery to avoid disappearing or slow avatars.
class ProfileNotifier extends ChangeNotifier {
  ProfileState _state = const ProfileState.initial();

  /// Current profile state
  ProfileState get state => _state;

  /// Convenience getters for backward compatibility
  String? get userName => _state.userName;
  String? get profileImageUrl => _state.profileImageUrl;
  String? get localImagePath => _state.localImagePath;
  ProfileStatus get status => _state.status;
  String? get errorMessage => _state.errorMessage;

  /// Carga instantáneamente los datos de perfil desde la memoria local y disco (0ms)
  Future<void> loadFromLocalCache(String userId) async {
    try {
      final cacheData = await PreferenceService().getUserProfileCache();
      final cachedName = cacheData['name'];
      final cachedUrl = cacheData['imageUrl'];
      var localPath = cacheData['localImagePath'];

      // Verificar si el archivo local existe en disco
      if (localPath != null && localPath.isNotEmpty) {
        final file = File(localPath);
        if (!await file.exists() || await file.length() == 0) {
          localPath = null;
        }
      }

      // Si no hay ruta en preferencias pero existe el archivo en ProfileCacheService
      localPath ??= await ProfileCacheService().getLocalImagePath(userId);

      if (cachedName != null || cachedUrl != null || localPath != null) {
        _updateState(ProfileState.loaded(
          userName: cachedName ?? _state.userName,
          profileImageUrl: cachedUrl ?? _state.profileImageUrl,
          localImagePath: localPath ?? _state.localImagePath,
        ));
      }

      // Si tenemos URL pero no archivo local, iniciamos descarga en segundo plano
      final activeUrl = cachedUrl ?? _state.profileImageUrl;
      if (localPath == null && activeUrl != null && activeUrl.startsWith('http')) {
        _startBackgroundDownload(userId, activeUrl);
      }
    } catch (e) {
      debugPrint('ProfileNotifier: Error cargando desde caché local: $e');
    }
  }

  /// Sets the profile to loading state
  void setLoading() {
    _updateState(const ProfileState.loading());
  }

  /// Updates the profile data and sets to loaded state
  ///
  /// Persists to local preference cache and syncs disk image in background.
  void updateProfile({
    String? newName,
    String? newImageUrl,
    String? newLocalImagePath,
    String? userId,
  }) {
    final effectiveName = newName ?? _state.userName;
    final effectiveImageUrl = newImageUrl ?? _state.profileImageUrl;
    final effectiveLocalPath = newLocalImagePath ?? _state.localImagePath;

    final newState = ProfileState.loaded(
      userName: effectiveName,
      profileImageUrl: effectiveImageUrl,
      localImagePath: effectiveLocalPath,
    );

    if (_state != newState) {
      _updateState(newState);
    }

    // Persistir en preferencias para arranque instantáneo
    PreferenceService().saveUserProfileCache(
      name: effectiveName,
      imageUrl: effectiveImageUrl,
      localImagePath: effectiveLocalPath,
    );

    // Si hay URL y userId pero no archivo local, descargar a disco en segundo plano
    if (userId != null &&
        effectiveImageUrl != null &&
        effectiveImageUrl.startsWith('http') &&
        effectiveLocalPath == null) {
      _startBackgroundDownload(userId, effectiveImageUrl);
    }
  }

  void _startBackgroundDownload(String userId, String url) {
    ProfileCacheService().downloadAndCacheImage(userId, url).then((cachedFile) {
      if (cachedFile != null && cachedFile.existsSync()) {
        final updatedState = _state.copyWith(localImagePath: cachedFile.path);
        _updateState(updatedState);
        PreferenceService().saveUserProfileCache(
          localImagePath: cachedFile.path,
        );
      }
    }).catchError((e) {
      debugPrint('ProfileNotifier: Error en descarga en segundo plano: $e');
    });
  }

  /// Sets an error state with the given error message
  void setError(String error) {
    _updateState(ProfileState.error(error));
  }

  /// Clears the profile data, typically when signing out
  void clearProfile({String? userId}) {
    _updateState(const ProfileState.initial());
    PreferenceService().clearUserProfileCache();
    if (userId != null) {
      ProfileCacheService().clearCache(userId);
    }
  }

  /// Internal method to update state and notify listeners
  void _updateState(ProfileState newState) {
    _state = newState;
    notifyListeners();
  }
}