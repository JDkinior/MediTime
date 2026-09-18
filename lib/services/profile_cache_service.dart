import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Servicio encargado de almacenar y recuperar la imagen de perfil en el disco local
/// del dispositivo para garantizar carga instantánea (0ms) sin depender de red.
class ProfileCacheService {
  static final ProfileCacheService _instance = ProfileCacheService._internal();
  factory ProfileCacheService() => _instance;
  ProfileCacheService._internal();

  /// Obtiene la ruta del archivo de imagen de perfil para un usuario.
  Future<String> _getProfileFilePath(String userId) async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/profile_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return '${cacheDir.path}/user_${userId}_avatar.jpg';
  }

  /// Retorna el archivo local si existe en disco y tiene contenido válido.
  Future<File?> getLocalImageFile(String userId) async {
    try {
      final path = await _getProfileFilePath(userId);
      final file = File(path);
      if (await file.exists() && await file.length() > 0) {
        return file;
      }
    } catch (e) {
      debugPrint('ProfileCacheService: Error verificando archivo local: $e');
    }
    return null;
  }

  /// Retorna la ruta local del archivo si ya existe en disco.
  Future<String?> getLocalImagePath(String userId) async {
    final file = await getLocalImageFile(userId);
    return file?.path;
  }

  /// Guarda una imagen local (por ejemplo desde galería o cámara) en la caché del perfil.
  Future<File?> saveLocalImage(String userId, File sourceFile) async {
    try {
      final targetPath = await _getProfileFilePath(userId);
      final targetFile = File(targetPath);
      final bytes = await sourceFile.readAsBytes();
      await targetFile.writeAsBytes(bytes, flush: true);
      debugPrint('ProfileCacheService: Imagen local guardada en caché: $targetPath');
      return targetFile;
    } catch (e) {
      debugPrint('ProfileCacheService: Error guardando imagen local: $e');
      return null;
    }
  }

  /// Descarga la imagen remota desde la URL y la guarda de forma atómica en el disco.
  Future<File?> downloadAndCacheImage(String userId, String imageUrl) async {
    if (imageUrl.isEmpty || !imageUrl.startsWith('http')) return null;

    try {
      debugPrint('ProfileCacheService: Descargando imagen para caché: $imageUrl');
      final response = await http.get(Uri.parse(imageUrl)).timeout(
        const Duration(seconds: 12),
      );

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final targetPath = await _getProfileFilePath(userId);
        final targetFile = File(targetPath);
        await targetFile.writeAsBytes(response.bodyBytes, flush: true);
        debugPrint('ProfileCacheService: Imagen descargada y almacenada en: $targetPath');
        return targetFile;
      } else {
        debugPrint('ProfileCacheService: Falló la descarga HTTP con status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ProfileCacheService: Error descargando imagen remota: $e');
    }
    return null;
  }

  /// Elimina la imagen de la caché cuando el usuario cierra sesión o elimina su perfil.
  Future<void> clearCache(String userId) async {
    try {
      final path = await _getProfileFilePath(userId);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('ProfileCacheService: Caché eliminada para usuario $userId');
      }
    } catch (e) {
      debugPrint('ProfileCacheService: Error al limpiar caché: $e');
    }
  }
}
