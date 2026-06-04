import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/ticket_provider.dart';
import 'camera_screen.dart';

class CreateTicketPage extends ConsumerStatefulWidget {
  const CreateTicketPage({super.key});

  @override
  ConsumerState<CreateTicketPage> createState() => _CreateTicketPageState();
}

class _CreateTicketPageState extends ConsumerState<CreateTicketPage> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  bool _isSubmitting = false;
  XFile? _attachedPhoto;
  late final _ticketRepo = ref.watch(ticketRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleCreateTicket() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final currentUser = ref.read(currentUserProvider);
    
    // Convert photo to base64 if attached
    String? photoBase64;
    if (_attachedPhoto != null) {
      try {
        final bytes = await _attachedPhoto!.readAsBytes();
        photoBase64 = base64Encode(bytes);
      } catch (e) {
        print('Error converting photo to base64: $e');
      }
    }

    final ticket = await _ticketRepo.createTicket(
      _titleController.text,
      _descriptionController.text,
      currentUser?.username ?? 'unknown',
      photoPath: photoBase64,
    );

    if (!mounted) return;

    if (ticket != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ticket ${ticket.id} created successfully')),
      );
      ref.refresh(userTicketsProvider(currentUser?.username ?? ''));
      Navigator.pop(context);
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create ticket')),
      );
    }
  }

  void _handleCameraPermission() async {
    final status = await Permission.camera.request();
    
    if (!mounted) return;

    if (status.isGranted) {
      // Navigate to camera screen and await result
      final XFile? photo = await Navigator.of(context).push<XFile?>(
        MaterialPageRoute(
          builder: (_) => const CameraScreen(),
        ),
      );

      if (photo != null && mounted) {
        setState(() => _attachedPhoto = photo);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo attached successfully')),
        );
      }
    } else if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission denied')),
      );
    } else if (status.isPermanentlyDenied) {
      // Show dialog to open app settings
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Camera Permission'),
          content: const Text(
            'Camera permission is permanently denied. '
            'Please enable it in app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                openAppSettings();
                Navigator.pop(context);
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Ticket',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF000072),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Report a New Issue',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            // Title field
            const Text('Title', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              enabled: !_isSubmitting,
              maxLines: 1,
              decoration: InputDecoration(
                hintText: 'e.g., Laptop not working',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 20),
            // Description field
            const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              enabled: !_isSubmitting,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Describe the issue in detail...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 20),
            // Attached photo preview
            if (_attachedPhoto != null) ...[
              const Text('Attached Photo', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_attachedPhoto!.path),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'File: ${_attachedPhoto!.name}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _attachedPhoto = null),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Remove photo',
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            // Camera button
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _handleCameraPermission,
              icon: const Icon(Icons.camera_alt),
              label: Text(_attachedPhoto != null ? 'Change Photo' : 'Attach Photo (Camera)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 24),
            // Submit button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _handleCreateTicket,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Create Ticket'),
            ),
            const SizedBox(height: 12),
            // Cancel button
            OutlinedButton(
              onPressed: _isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
