import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadImage(Uint8List imageBytes, String fileName) async {
    final ref = _storage.ref().child('uploads/$fileName');
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    final task = await ref.putData(imageBytes, metadata);
    final downloadUrl = await task.ref.getDownloadURL();
    return downloadUrl;
  }
}
