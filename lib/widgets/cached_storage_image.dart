import 'package:flutter/material.dart';

class CachedStorageImage extends StatelessWidget {
  final String? imageUrl;
  final String? imagePath;

  const CachedStorageImage({super.key, this.imageUrl, this.imagePath});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.broken_image, color: Colors.white24, size: 48),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 200,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        },
        errorBuilder: (_, error, ___) => Container(
          height: 200,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, color: Colors.white24, size: 48),
              SizedBox(height: 8),
              Text('Immagine non disponibile',
                  style: TextStyle(color: Colors.white24, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
