// lib/services/storage_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;

/// Servicio de almacenamiento de imágenes usando Cloudinary.
/// 
/// Reemplaza Firebase Storage para evitar costos de almacenamiento.
/// Requiere configuración de Cloudinary en variables de entorno.
class StorageService {
  // Configuración de Cloudinary - obtener de variables de entorno o config
  // TODO: Reemplaza con tus valores reales del dashboard de Cloudinary.
  // El cloud name suele ser minúsculo y debe coincidir exactamente con el dashboard.
  static const String cloudinaryCloudName = 'daoq4metj';
  static const String cloudinaryUploadPreset = 'meditime_upload';

  bool get _hasValidConfiguration {
    return cloudinaryCloudName.isNotEmpty &&
        cloudinaryCloudName != 'YOUR_CLOUD_NAME' &&
        cloudinaryUploadPreset.isNotEmpty &&
        cloudinaryUploadPreset != 'YOUR_UNSIGNED_UPLOAD_PRESET';
  }

  /// Comprime una imagen a 300x300px con calidad 70%
  Future<Uint8List> _compressImage(File imageFile) async {
    try {
      final originalImage = img.decodeImage(await imageFile.readAsBytes());
      if (originalImage == null) {
        throw Exception('No se pudo decodificar la imagen');
      }
      final resizedImage = img.copyResize(originalImage, width: 300);
      final compressedImage = img.encodeJpg(resizedImage, quality: 70);
      return Uint8List.fromList(compressedImage);
    } catch (e) {
      debugPrint('Error al comprimir imagen: $e');
      rethrow;
    }
  }

  /// Sube una imagen de perfil a Cloudinary.
  /// 
  /// Retorna la URL pública de la imagen almacenada.
  /// Utiliza upload sin credenciales (unsigned) para mayor seguridad.
  Future<String> uploadProfileImage(String userId, File imageFile) async {
    try {
      debugPrint('StorageService: Iniciando subida de imagen de perfil para usuario $userId');

      if (!_hasValidConfiguration) {
        throw Exception(
          'Cloudinary no está configurado. Reemplaza cloudinaryCloudName y cloudinaryUploadPreset con valores reales.',
        );
      }
      
      // Comprimir imagen
      Uint8List compressedImage = await _compressImage(imageFile);
      
      // Crear petición multipart para Cloudinary
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload',
        ),
      );

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Agregar archivo comprimido
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          compressedImage,
          filename: 'profile_$userId.jpg',
        ),
      );

      // Agregar parámetros de Cloudinary
      request.fields['upload_preset'] = cloudinaryUploadPreset;
      request.fields['public_id'] = 'profile_${userId}_$timestamp';
      request.fields['folder'] = 'meditime/profiles';

      // Enviar petición
      debugPrint('StorageService: Enviando petición a Cloudinary...');
      var response = await request.send();

      // Procesar respuesta
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        debugPrint('StorageService: Respuesta exitosa de Cloudinary');

        final responseJson = jsonDecode(responseBody) as Map<String, dynamic>;
        final rawUrl = responseJson['secure_url'] as String?;

        if (rawUrl == null || rawUrl.isEmpty) {
          throw Exception('Cloudinary no devolvió secure_url');
        }

        // Agregar timestamp como query param (?t=...) para que Flutter e HTTP invaliden la caché
        // mientras Cloudinary sobrescribe y mantiene sólo 1 imagen por usuario.
        final downloadUrl = '$rawUrl?t=$timestamp';

        debugPrint('StorageService: Imagen subida exitosamente. URL: $downloadUrl');
        return downloadUrl;
      } else {
        final responseBody = await response.stream.bytesToString();
        debugPrint('StorageService: Error en respuesta de Cloudinary - Status: ${response.statusCode}');
        debugPrint('StorageService: Response body: $responseBody');
        if (response.statusCode == 401) {
          throw Exception(
            'Cloudinary rechazó la subida (401). Verifica que el cloud name sea exacto y que el upload preset exista y esté marcado como Unsigned.',
          );
        }
        throw Exception(
          'Error al subir a Cloudinary (${response.statusCode})',
        );
      }
    } catch (e) {
      debugPrint('StorageService: Error al subir la imagen: $e');
      rethrow;
    }
  }
}