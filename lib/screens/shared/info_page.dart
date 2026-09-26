// lib/screens/shared/info_page.dart
import 'package:flutter/material.dart';
import 'package:meditime/widgets/modern_app_bar.dart';

class InfoPage extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const InfoPage({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        child: AppBar(
          title: Text(title),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}