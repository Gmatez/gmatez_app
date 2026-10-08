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

class HostIdentityStep extends StatelessWidget {
  const HostIdentityStep({
    super.key,
    required this.number,
    required this.images,
    required this.uploading,
    required this.onNumberChanged,
    required this.onPicked,
  });

  final TextEditingController number;
  final HostIdentityImages images;
  final bool uploading;
  final ValueChanged<String> onNumberChanged;
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
              'Your identity card number, both sides of the card, and a profile photo are required. An admin still reviews the application.',
        ),
        const SizedBox(height: AppSpacing.lg),
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
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file == null) {
      return;
    }
    final bytes = await file.readAsBytes();
    if (!context.mounted) {
      return;
    }
    if (bytes.length > 1500000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Each image must be under 1.5 MB.')),
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
