import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meditime/screens/loading_screen.dart';
import 'package:meditime/screens/login_page.dart';
import 'home_page.dart';
import 'package:meditime/data/perfil_data.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _profileImagePath;
  List<String>? _nameParts;
  bool _isLoading = true;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(_handleAuthStateChange);
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
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _nameParts = (data?[PerfilData.keyName] as String?)?.split(' ') ?? [];
          _profileImagePath = data?[PerfilData.keyProfileImage] as String? ?? '';
        });
      }
    } catch (e) {
      print('Error al cargar datos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingScreen()
        : StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return snapshot.hasData
                  ? HomePage(
                      nameParts: _nameParts,
                      profileImagePath: _profileImagePath,
                    )
                  : const LoginPage();
            },
          );
  }
}