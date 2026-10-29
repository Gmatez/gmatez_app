import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';

import '../../app/theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.imageBytes,
    this.size = 48,
    this.online,
  });

  final String name;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final double size;
  final bool? online;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    final image = imageUrl;
    final avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.surfaceMuted,
      foregroundColor: AppColors.primary,
      backgroundImage: imageBytes != null
          ? MemoryImage(imageBytes!)
          : image != null && image.isNotEmpty
          ? CachedNetworkImageProvider(image)
          : null,
      child: (imageBytes == null && (image == null || image.isEmpty))
          ? Text(
              initials,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: size * 0.32,
              ),
            )
          : null,
    );

    if (online == null) {
      return avatar;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: online! ? AppColors.success : AppColors.textSecondary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}
