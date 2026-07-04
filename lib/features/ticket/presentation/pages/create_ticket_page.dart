import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/ticket_provider.dart';
import 'camera_screen.dart';

class CreateTicketPage extends ConsumerStatefulWidget {
  const CreateTicketPage({super.key});

  @override
  ConsumerState<CreateTicketPage> createState() => _CreateTicketPageState();
}

class _CreateTicketPageState extends ConsumerState<CreateTicketPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;
  XFile? _attachedPhoto;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateTicket() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not authenticated')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final ticketRepo = ref.read(ticketRepositoryProvider);
      
      // Upload photo if attached
      String? photoUrl;
      if (_attachedPhoto != null) {
        // For now, store base64 - in production, upload to Supabase Storage
        // photoUrl = await ticketRepo.uploadPhoto(...);
      }

      final ticket = await ticketRepo.createTicket(
        title: _titleController.text,
        description: _descriptionController.text,
        idUser: currentUser.idUser,
        photoPath: photoUrl,
      );

      if (!mounted) return;

      if (ticket != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ticket #${ticket.idTicket} created successfully')),
        );
        
        // Refresh user tickets
        ref.invalidate(userTicketsProvider(currentUser.idUser));
        
        Navigator.pop(context);
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create ticket')),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _handleCameraPermission() async {
    final status = await Permission.camera.request();

    if (!mounted) return;

    if (status.isGranted) {
      final XFile? photo = await Navigator.of(context).push<XFile?>(
        MaterialPageRoute(builder: (_) => const CameraScreen()),
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
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Camera Permission'),
          content: const Text('Camera permission is permanently denied. Please enable it in app settings.'),
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
                      child: CircularProgressIndicator(strokeWidth: 2),
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
