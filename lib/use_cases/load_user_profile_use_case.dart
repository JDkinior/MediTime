// lib/use_cases/load_user_profile_use_case.dart
import 'package:flutter/material.dart';
import 'package:meditime/core/result.dart';
import 'package:meditime/repositories/user_repository.dart';

/// Use case for loading user profile data.
/// 
/// This class encapsulates the business logic for loading and processing
/// user profile information from the repository.
class LoadUserProfileUseCase {
  final UserRepository _userRepository;

  const LoadUserProfileUseCase(this._userRepository);

  /// Loads the user profile for the given user ID.
  /// 
  /// Returns a Result containing the profile data as a Map, or an error message.
  Future<Result<Map<String, dynamic>?>> execute(String userId) async {
    try {
      debugPrint('LoadUserProfileUseCase: Loading profile for user $userId');
      
      final result = await _userRepository.getUserProfile(userId);
      
      if (result.isFailure) {
        debugPrint('LoadUserProfileUseCase: Failed to load profile: ${result.error}');
        return Result.failure(result.error!);
      }
      
      final doc = result.data!;
      final profileData = doc.data() as Map<String, dynamic>?;
      
      debugPrint('LoadUserProfileUseCase: Profile loaded successfully');
      return Result.success(profileData);
      
    } catch (e) {
      debugPrint('LoadUserProfileUseCase: Unexpected error: $e');
      return Result.failure('Error al cargar el perfil: $e');
    }
  }
}