import 'package:flutter/material.dart';

const _proxyBase =
    'https://europe-west1-saleslot-app.cloudfunctions.net/imageProxy';

class CachedStorageImage extends StatelessWidget {
  final String? imageUrl;
  final String? imagePath;

  const CachedStorageImage({super.key, this.imageUrl, this.imagePath});

  String? get _url {
    if (imagePath != null && imagePath!.isNotEmpty) {
      return '$_proxyBase?path=${Uri.encodeComponent(imagePath!)}';
    }
    return imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url == null || url.isEmpty) {
      return _placeholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        onTap: () => _openFullscreen(context, url),
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
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Center(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
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
}
