// lib/services/storage_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<Uint8List> _compressImage(File imageFile) async {
    final originalImage = img.decodeImage(await imageFile.readAsBytes());
    if (originalImage == null) {
      throw Exception('No se pudo decodificar la imagen');
    }
    final resizedImage = img.copyResize(originalImage, width: 300);
    final compressedImage = img.encodeJpg(resizedImage, quality: 70);
    return Uint8List.fromList(compressedImage);
  }

  Future<String> uploadProfileImage(String userId, File imageFile) async {
    try {
      Uint8List compressedImage = await _compressImage(imageFile);
      String fileName = 'profile_images/$userId.jpg';
      Reference storageRef = _storage.ref().child(fileName);
      
      await storageRef.putData(compressedImage);
      
      String downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Error al subir la imagen: $e");
      rethrow; // Lanza el error para que la UI pueda manejarlo
    }
  }
}