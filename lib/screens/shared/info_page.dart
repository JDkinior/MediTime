import 'package:flutter/material.dart';
import 'package:meditime/widgets/modern_app_bar.dart';
import 'package:meditime/widgets/modern_content_fade.dart';

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
      body: ModernContentFade(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }
}