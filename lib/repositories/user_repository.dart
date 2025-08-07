// lib/repositories/user_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meditime/core/result.dart';

/// Abstract repository interface for user profile operations.
/// 
/// This interface defines the contract for user data operations,
/// allowing for different implementations (Firestore, local storage, etc.)
abstract class UserRepository {
  /// Saves or updates user profile data
  Future<Result<void>> saveUserProfile(String userId, Map<String, dynamic> data);
  
  /// Gets user profile data
  Future<Result<DocumentSnapshot>> getUserProfile(String userId);
}