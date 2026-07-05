import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/ticket_model.dart';
import '../providers/ticket_provider.dart';
import 'camera_screen.dart';

class CreateTicketPage extends ConsumerStatefulWidget {
  /// Optional ticket — if provided, page runs in EDIT mode
  final Ticket? ticket;

  const CreateTicketPage({super.key, this.ticket});

  bool get isEditMode => ticket != null;

  @override
  ConsumerState<CreateTicketPage> createState() => _CreateTicketPageState();
}

class _CreateTicketPageState extends ConsumerState<CreateTicketPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;
  XFile? _attachedPhoto;
  String? _existingPhotoUrl; // for edit mode — preserve URL if no new photo

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode) {
      _titleController.text = widget.ticket!.title;
      _descriptionController.text = widget.ticket!.description;
      _existingPhotoUrl = widget.ticket!.photoPath;
    }
  }

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

      // =============== EDIT MODE ===============
      if (widget.isEditMode) {
        final existing = widget.ticket!;

        // Upload new photo if attached, otherwise keep existing URL
        String? finalPhotoPath = _existingPhotoUrl;
        if (_attachedPhoto != null) {
          final uploaded = await ticketRepo.uploadPhoto(
            existing.idTicket,
            _attachedPhoto!.path,
            _attachedPhoto!.name,
          );
          if (uploaded != null) finalPhotoPath = uploaded;
        }

        // Update ticket
        final updated = await ticketRepo.updateTicket(
          idTicket: existing.idTicket,
          title: _titleController.text,
          description: _descriptionController.text,
          photoPath: finalPhotoPath,
        );

        if (!mounted) return;
        if (updated != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ticket #${existing.idTicket} updated')),
          );
          ref.invalidate(ticketDetailProvider(existing.idTicket));
          ref.invalidate(userTicketsProvider(currentUser.idUser));
          ref.invalidate(fetchAllTicketsProvider);
          Navigator.pop(context, true); // return success
        } else {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update ticket (status may have changed)')),
          );
        }
        return;
      }

      // =============== CREATE MODE ===============
      final ticket = await ticketRepo.createTicket(
        title: _titleController.text,
        description: _descriptionController.text,
        idUser: currentUser.idUser,
        photoPath: null,
      );

      if (ticket == null) {
        setState(() => _isSubmitting = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create ticket')),
        );
        return;
      }

      // Upload photo if attached, then update ticket
      if (_attachedPhoto != null) {
        try {
          final photoPath = await ticketRepo.uploadPhoto(
            ticket.idTicket,
            _attachedPhoto!.path,
            _attachedPhoto!.name,
          );
          if (photoPath != null) {
            await ticketRepo.updateTicket(
              idTicket: ticket.idTicket,
              title: _titleController.text,
              description: _descriptionController.text,
              photoPath: photoPath,
            );
            ref.invalidate(ticketDetailProvider(ticket.idTicket));
            ref.invalidate(userTicketsProvider(currentUser.idUser));
            ref.invalidate(fetchAllTicketsProvider);
          }
        } catch (e) {
          print('Error uploading photo: $e');
        }
      }

      if (!mounted) return;

      if (ticket != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ticket #${ticket.idTicket} created successfully')),
        );
        ref.invalidate(userTicketsProvider(currentUser.idUser));
        Navigator.pop(context, true);
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
        title: Text(
          widget.isEditMode ? 'Edit Ticket #${widget.ticket!.idTicket}' : 'Create Ticket',
          style: const TextStyle(color: Colors.white),
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
            Text(
              widget.isEditMode ? 'Edit Ticket Details' : 'Report a New Issue',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

            // Attached photo preview (newly captured)
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

            // Existing photo (edit mode only, shown when no new photo picked)
            if (widget.isEditMode &&
                _attachedPhoto == null &&
                _existingPhotoUrl != null &&
                _existingPhotoUrl!.isNotEmpty) ...[
              const Text('Current Photo', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  child: Image.network(
                    _existingPhotoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Camera button
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _handleCameraPermission,
              icon: const Icon(Icons.camera_alt),
              label: Text(_attachedPhoto != null
                  ? 'Change Photo'
                  : (widget.isEditMode ? 'Replace Photo (Camera)' : 'Attach Photo (Camera)')),
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
                  : Text(widget.isEditMode ? 'Update Ticket' : 'Create Ticket'),
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
