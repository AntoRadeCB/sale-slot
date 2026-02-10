import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CachedStorageImage extends StatefulWidget {
  final String? imageUrl;
  final String? imagePath;

  const CachedStorageImage({super.key, this.imageUrl, this.imagePath});

  @override
  State<CachedStorageImage> createState() => _CachedStorageImageState();
}

class _CachedStorageImageState extends State<CachedStorageImage> {
  String? _resolvedUrl;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _resolveUrl();
  }

  Future<void> _resolveUrl() async {
    try {
      // Try getting download URL from Storage SDK using path
      if (widget.imagePath != null) {
        final ref = FirebaseStorage.instance.ref(widget.imagePath!);
        final url = await ref.getDownloadURL();
        if (mounted) setState(() { _resolvedUrl = url; _loading = false; });
        return;
      }
      // Fallback to stored URL
      if (widget.imageUrl != null) {
        if (mounted) setState(() { _resolvedUrl = widget.imageUrl; _loading = false; });
        return;
      }
      if (mounted) setState(() { _loading = false; _error = true; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (_error || _resolvedUrl == null) {
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
        _resolvedUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 200,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          height: 200,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image, color: Colors.white24, size: 48),
        ),
      ),
    );
  }
}
