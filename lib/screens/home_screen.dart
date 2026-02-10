import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import 'reports_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _imageBytes;
  bool _uploading = false;
  String? _uploadedUrl;

  Future<void> _pickAndUpload({required ImageSource source}) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _uploading = true;
        _uploadedUrl = null;
      });

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      final url = await _storageService.uploadImage(bytes, fileName);

      setState(() {
        _uploading = false;
        _uploadedUrl = url;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Immagine caricata! Elaborazione in corso...'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _uploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎰 SaleSlot'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Report',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportsScreen()),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Preview
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: _imageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_outlined,
                              size: 64, color: Colors.white24),
                          SizedBox(height: 12),
                          Text('Scatta o carica un report',
                              style: TextStyle(color: Colors.white38)),
                        ],
                      ),
              ),
              const SizedBox(height: 32),

              if (_uploading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Caricamento in corso...'),
                const SizedBox(height: 32),
              ],

              if (_uploadedUrl != null) ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 8),
                const Text('Upload completato! In elaborazione...',
                    style: TextStyle(color: Colors.green)),
                const SizedBox(height: 32),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionButton(
                    icon: Icons.camera_alt,
                    label: 'Scatta',
                    onTap: _uploading
                        ? null
                        : () => _pickAndUpload(source: ImageSource.camera),
                  ),
                  const SizedBox(width: 16),
                  _ActionButton(
                    icon: Icons.photo_library,
                    label: 'Galleria',
                    onTap: _uploading
                        ? null
                        : () => _pickAndUpload(source: ImageSource.gallery),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
                ),
                icon: const Icon(Icons.analytics),
                label: const Text('Vedi Report'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
