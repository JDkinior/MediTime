// lib/repositories/firestore_user_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:meditime/core/result.dart';
import 'package:meditime/core/constants.dart';
import 'package:meditime/repositories/user_repository.dart';

/// Firestore implementation of the UserRepository.
/// 
/// Handles all user profile-related database operations using Cloud Firestore.
/// Uses constants for consistent field names and error messages.
class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<Result<void>> saveUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      await _db
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .set(data, SetOptions(merge: true));
      return const Result.success(null);
    } catch (e) {
      debugPrint('Error saving user profile: $e');
      return const Result.failure(AppConstants.profileLoadErrorMessage);
    }
  }

  @override
  Future<Result<DocumentSnapshot>> getUserProfile(String userId) async {
    try {
      final doc = await _db
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();
      return Result.success(doc);
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return const Result.failure(AppConstants.profileLoadErrorMessage);
    }
  }
}