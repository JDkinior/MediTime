import 'dart:io';
import 'package:flutter/material.dart';
import 'package:meditime/theme/app_theme.dart';

/// Un widget de avatar optimizado que garantiza:
/// 1. Carga instantánea desde disco si existe archivo en caché (0ms).
/// 2. Ninguna pantalla o círculo en blanco mientras se descarga de la red.
/// 3. Tolerancia total a fallos de conexión (offline o modo avión) mostrando el icono correspondiente.
class ProfileAvatar extends StatelessWidget {
  final double radius;
  final String? localImagePath;
  final String? imageUrl;
  final bool isAnimalMode;
  final Color? backgroundColor;
  final Color? iconColor;

  const ProfileAvatar({
    super.key,
    this.radius = 34,
    this.localImagePath,
    this.imageUrl,
    this.isAnimalMode = false,
    this.backgroundColor,
    this.iconColor,
  });

  bool _isDeprecatedFirebaseStorageUrl(String? url) {
    return url != null && url.contains('firebasestorage.googleapis.com');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBgColor = backgroundColor ?? (isDark ? const Color(0xFF1E293B) : Colors.white);
    final defaultIconColor = iconColor ?? (isDark ? Colors.white70 : AppTheme.primaryColor);

    final placeholderIcon = Icon(
      isAnimalMode ? Icons.pets_rounded : Icons.person,
      size: radius * 1.05,
      color: defaultIconColor,
    );

    // 1. Prioridad máxima: Archivo local en disco (0ms de latencia, instantáneo)
    if (localImagePath != null && localImagePath!.isNotEmpty) {
      final file = File(localImagePath!);
      if (file.existsSync()) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: defaultBgColor,
          backgroundImage: FileImage(file),
          child: null,
        );
      }
    }

    // 2. Si hay URL remota válida
    final hasValidRemoteUrl = imageUrl != null &&
        imageUrl!.isNotEmpty &&
        imageUrl!.startsWith('http') &&
        !_isDeprecatedFirebaseStorageUrl(imageUrl);

    if (hasValidRemoteUrl) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: defaultBgColor,
        ),
        child: ClipOval(
          child: Image.network(
            imageUrl!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              // Mientras carga la red, mostramos el icono con opacidad suave en vez de un círculo vacío
              return Center(
                child: Opacity(
                  opacity: 0.6,
                  child: placeholderIcon,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              // Si falla la red o está offline, mostramos el icono
              return Center(child: placeholderIcon);
            },
          ),
        ),
      );
    }

    // 3. Si no hay imagen, mostrar icono por defecto
    return CircleAvatar(
      radius: radius,
      backgroundColor: defaultBgColor,
      child: placeholderIcon,
    );
  }
}
