// lib/notifiers/subscription_notifier.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:meditime/core/constants.dart';
import 'package:meditime/models/usuario.dart';
import 'package:meditime/services/subscription_service.dart';

/// Notifier that manages the user's subscription state and feature gating.
class SubscriptionNotifier extends ChangeNotifier {
  bool _isPremium = false;
  String? _subscriptionTier = 'free';
  DateTime? _subscriptionExpiresAt;
  bool _isLoading = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscriptionStream;

  // Maximum active treatments allowed for free users
  static const int freeTreatmentsLimit = 3;
  // Maximum caregiver/animal profiles allowed for free users (0 additional or 1)
  static const int freeProfilesLimit = 1;

  bool get isPremium {
    if (!_isPremium) return false;
    if (_subscriptionExpiresAt != null && _subscriptionExpiresAt!.isBefore(DateTime.now())) {
      return false; // Expired
    }
    return true;
  }

  String? get subscriptionTier => _subscriptionTier;
  DateTime? get subscriptionExpiresAt => _subscriptionExpiresAt;
  bool get isLoading => _isLoading;

  /// Business logic gates
  bool canAddTreatment(int currentActiveTreatmentsCount) {
    if (isPremium) return true;
    return currentActiveTreatmentsCount < freeTreatmentsLimit;
  }

  bool canAddCaregiverProfile(int currentProfilesCount) {
    if (isPremium) return true;
    return currentProfilesCount < freeProfilesLimit;
  }

  bool get canExportPdf => isPremium;
  bool get canUseVoiceAssistant => isPremium;
  bool get canUseHomeWidgets => isPremium;

  /// Initializes listening to user's subscription in Firestore
  void listenToUser(String? userId, SubscriptionService service) {
    _subscriptionStream?.cancel();
    _subscriptionStream = null;

    if (userId == null) {
      _isPremium = false;
      _subscriptionTier = 'free';
      _subscriptionExpiresAt = null;
      notifyListeners();
      return;
    }

    _subscriptionStream = service.getSubscriptionStream(userId).listen((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _isPremium = data[AppConstants.isPremiumField] as bool? ?? false;
        _subscriptionTier = data[AppConstants.subscriptionTierField] as String? ?? 'free';
        
        final expiresStr = data[AppConstants.subscriptionExpiresAtField] as String?;
        if (expiresStr != null && expiresStr.isNotEmpty) {
          _subscriptionExpiresAt = DateTime.tryParse(expiresStr);
        } else {
          _subscriptionExpiresAt = null;
        }
      } else {
        _isPremium = false;
        _subscriptionTier = 'free';
        _subscriptionExpiresAt = null;
      }
      notifyListeners();
    }, onError: (err) {
      debugPrint('Error in subscription stream: $err');
    });
  }

  /// Updates state directly from a loaded Usuario object
  void updateFromUser(Usuario? user) {
    if (user == null) {
      _isPremium = false;
      _subscriptionTier = 'free';
      _subscriptionExpiresAt = null;
    } else {
      _isPremium = user.isPremium;
      _subscriptionTier = user.subscriptionTier ?? 'free';
      _subscriptionExpiresAt = user.subscriptionExpiresAt;
    }
    notifyListeners();
  }

  /// Activates a plan
  Future<void> activateSubscription({
    required String userId,
    required String tier,
    required SubscriptionService service,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await service.activateSubscription(userId, tier: tier);
      _isPremium = true;
      _subscriptionTier = tier;
      final now = DateTime.now();
      _subscriptionExpiresAt = tier == 'annual'
          ? DateTime(now.year + 1, now.month, now.day)
          : DateTime(now.year, now.month + 1, now.day);
    } catch (e) {
      debugPrint('Error activating subscription: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cancels plan
  Future<void> cancelSubscription({
    required String userId,
    required SubscriptionService service,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await service.cancelSubscription(userId);
      _isPremium = false;
      _subscriptionTier = 'free';
      _subscriptionExpiresAt = null;
    } catch (e) {
      debugPrint('Error cancelling subscription: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscriptionStream?.cancel();
    super.dispose();
  }
}
