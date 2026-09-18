// lib/services/subscription_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:meditime/core/constants.dart';

/// Service responsible for managing user subscriptions, tiers, and expiration.
class SubscriptionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream to listen to real-time changes in user's subscription.
  Stream<DocumentSnapshot<Map<String, dynamic>>> getSubscriptionStream(String userId) {
    return _db.collection(AppConstants.usersCollection).doc(userId).snapshots();
  }

  /// Updates the user's subscription status in Firestore.
  Future<void> updateSubscription({
    required String userId,
    required bool isPremium,
    String? tier, // 'monthly', 'annual', or 'free'
    DateTime? expiresAt,
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        AppConstants.isPremiumField: isPremium,
        AppConstants.subscriptionTierField: tier,
        AppConstants.subscriptionExpiresAtField: expiresAt?.toIso8601String(),
      };

      await _db
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .set(updateData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating subscription in Firestore: $e');
      rethrow;
    }
  }

  /// Simulates/purchases a subscription plan for testing or integration.
  Future<void> activateSubscription(String userId, {required String tier}) async {
    final now = DateTime.now();
    final expiresAt = tier == 'annual'
        ? DateTime(now.year + 1, now.month, now.day)
        : DateTime(now.year, now.month + 1, now.day);

    await updateSubscription(
      userId: userId,
      isPremium: true,
      tier: tier,
      expiresAt: expiresAt,
    );
  }

  /// Cancels or resets the subscription to Free tier.
  Future<void> cancelSubscription(String userId) async {
    await updateSubscription(
      userId: userId,
      isPremium: false,
      tier: 'free',
      expiresAt: null,
    );
  }
}
