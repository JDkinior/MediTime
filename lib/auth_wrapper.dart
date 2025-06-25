// lib/auth_wrapper.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meditime/services/auth_service.dart'; // Ya usa el servicio, ¡bien!
import 'package:meditime/services/firestore_service.dart';
import 'package:provider/provider.dart';

// CAMBIO: Actualizar imports de las pantallas
import 'package:meditime/screens/shared/loading_screen.dart';
import 'package:meditime/screens/auth/login_page.dart';
import 'package:meditime/screens/home/home_page.dart';


class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _profileImagePath;
  List<String>? _nameParts;
  StreamSubscription<User?>? _authSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final authService = context.read<AuthService>();
    _authSubscription = authService.authStateChanges.listen(_handleAuthStateChange);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleAuthStateChange(User? user) async {
    setState(() => _isLoading = true);
    
    if (user == null) {
      setState(() {
        _profileImagePath = null;
        _nameParts = null;
        _isLoading = false;
      });
    } else {
      await _loadProfileData(user);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProfileData(User user) async {
    final firestoreService = context.read<FirestoreService>();
    try {
      final doc = await firestoreService.getUserProfile(user.uid);

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (mounted) {
          setState(() {
            _nameParts = (data?['name'] as String?)?.split(' ');
            _profileImagePath = data?['profileImage'] as String? ?? '';
          });
        }
      }
    } catch (e) {
      print('Error al cargar datos en AuthWrapper: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return _isLoading
      ? const LoadingScreen()
      : StreamBuilder<User?>(
          stream: authService.authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingScreen();
            }
            if (snapshot.hasData) {
              return HomePage(
                nameParts: _nameParts,
                profileImagePath: _profileImagePath,
              );
            }
            return const LoginPage();
          },
        );
  }
}