import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_layout.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';

class HostIdentityImages {
  const HostIdentityImages({
    this.front,
    this.back,
    this.profile,
    this.frontMime,
    this.backMime,
    this.profileMime,
  });

  final Uint8List? front;
  final Uint8List? back;
  final Uint8List? profile;
  final String? frontMime;
  final String? backMime;
  final String? profileMime;
}

const kIdentityDocumentTypes = <String, String>{
  'AADHAAR': 'Aadhaar',
  'PAN': 'PAN',
  'PASSPORT': 'Passport',
  'DRIVING_LICENCE': 'Driving licence',
  'VOTER_ID': 'Voter ID',
};

class HostIdentityStep extends StatelessWidget {
  const HostIdentityStep({
    super.key,
    required this.number,
    required this.documentType,
    required this.images,
    required this.uploading,
    required this.onNumberChanged,
    required this.onDocumentTypeChanged,
    required this.onPicked,
  });

  final TextEditingController number;
  final String documentType;
  final HostIdentityImages images;
  final bool uploading;
  final ValueChanged<String> onNumberChanged;
  final ValueChanged<String> onDocumentTypeChanged;
  final void Function(String slot, Uint8List bytes, String mime) onPicked;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppLayout.pagePadding(context).copyWith(
        top: AppSpacing.lg,
        bottom: AppSpacing.lg,
      ),
      children: [
        const ScreenHeader(
          title: 'Identity documents',
          subtitle:
              'Choose the document type, enter the number, and add both sides plus a profile photo. An admin reviews the upload manually.',
        ),
        const SizedBox(height: AppSpacing.lg),
        DropdownButtonFormField<String>(
          initialValue: kIdentityDocumentTypes.containsKey(documentType)
              ? documentType
              : 'AADHAAR',
          decoration: const InputDecoration(labelText: 'Document type'),
          items: [
            for (final entry in kIdentityDocumentTypes.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: uploading
              ? null
              : (value) {
                  if (value != null) onDocumentTypeChanged(value);
                },
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: number,
          enabled: !uploading,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Identity card number',
            hintText: 'Required',
          ),
          onChanged: onNumberChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        _ImageSlot(
          label: 'Identity card front',
          bytes: images.front,
          busy: uploading,
          onPick: () => _pick(context, 'front'),
        ),
        const SizedBox(height: 12),
        _ImageSlot(
          label: 'Identity card back',
          bytes: images.back,
          busy: uploading,
          onPick: () => _pick(context, 'back'),
        ),
        const SizedBox(height: 12),
        _ImageSlot(
          label: 'Profile image',
          bytes: images.profile,
          busy: uploading,
          onPick: () => _pick(context, 'profile'),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context, String slot) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) {
      return;
    }
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 70,
    );
    if (file == null) {
      return;
    }
    final bytes = await file.readAsBytes();
    if (!context.mounted) {
      return;
    }
    if (bytes.length > 4000000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Each image must be under 4 MB.')),
      );
      return;
    }
    final lower = file.name.toLowerCase();
    final mime = lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.webp')
        ? 'image/webp'
        : 'image/jpeg';
    onPicked(slot, bytes, mime);
  }
}

class _ImageSlot extends StatelessWidget {
  const _ImageSlot({
    required this.label,
    required this.bytes,
    required this.busy,
    required this.onPick,
  });

  final String label;
  final Uint8List? bytes;
  final bool busy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: bytes == null
                    ? const ColoredBox(
                        color: AppColors.surfaceMuted,
                        child: Icon(Icons.image_outlined),
                      )
                    : Image.memory(bytes!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : onPick,
                child: Text(bytes == null ? 'Add image' : 'Replace image'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
