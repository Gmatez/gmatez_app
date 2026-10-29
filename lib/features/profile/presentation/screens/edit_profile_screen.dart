import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/constants/speaking_languages.dart';
import '../../../../core/di/core_providers.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../discovery/presentation/state/discovery_notifier.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/validators/profile_validators.dart';
import '../state/profile_notifier.dart';
import '../state/profile_state.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _country = TextEditingController();
  String _language = 'en';
  String? _avatarUrl;
  Uint8List? _photo;
  String _gender = 'UNSPECIFIED';
  bool _discoverable = true;
  String? _localError;
  var _hydrated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myProfileNotifierProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _country.dispose();
    super.dispose();
  }

  void _hydrate(UserProfile profile) {
    if (_hydrated) {
      return;
    }
    _hydrated = true;
    _name.text = profile.displayName;
    _bio.text = profile.bio;
    _language = speakingLanguages.containsKey(profile.language)
        ? profile.language!
        : 'en';
    _country.text = profile.country ?? '';
    _avatarUrl = profile.avatarUrl;
    _gender = profile.gender;
    _discoverable = profile.isDiscoverable;
  }

  Future<void> _save() async {
    final error =
        ProfileValidators.displayName(_name.text) ??
        ProfileValidators.bio(_bio.text) ??
        ProfileValidators.country(_country.text);
    setState(() => _localError = error);
    if (error != null) {
      return;
    }
    if (_photo != null) {
      final uploaded = await ref.read(apiClientProvider).post<void>(
        ApiPaths.profileAvatar,
        body: {
          'mime': 'image/jpeg',
          'dataBase64': base64Encode(_photo!),
        },
        parser: (_) {},
      );
      if (!mounted) return;
      if (uploaded case Failure(:final failure)) {
        setState(() => _localError = failure.userMessage);
        return;
      }
    }
    final ok = await ref
        .read(myProfileNotifierProvider.notifier)
        .save(
          ProfileUpdate(
            displayName: _name.text.trim(),
            bio: _bio.text,
            language: _language,
            country: _country.text.trim().isEmpty
                ? null
                : _country.text.trim().toUpperCase(),
            gender: _gender,
            isDiscoverable: _discoverable,
          ),
        );
    if (ok && mounted) {
      ref.invalidate(discoveryNotifierProvider);
      context.pop();
    }
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 75,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 4000000) {
      setState(() => _localError = 'Photo must be under 4 MB.');
      return;
    }
    setState(() {
      _photo = bytes;
      _localError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(myProfileNotifierProvider, (previous, next) {
      final profile = next.profile;
      if (profile != null && !_hydrated) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _hydrate(profile);
          setState(() {});
        });
      }
    });
    final state = ref.watch(myProfileNotifierProvider);
    final profile = state.profile;

    if (state.status == ProfileViewStatus.loading && profile == null) {
      return const Scaffold(
        body: ScreenSkeleton.profile(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(
                children: [
                  UserAvatar(
                    name: _name.text,
                    imageUrl: _photo == null ? _avatarUrl : null,
                    imageBytes: _photo,
                    size: 88,
                  ),
                  TextButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Upload photo'),
                  ),
                ],
              ),
            ),
            AppTextField(controller: _name, label: 'Display name'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: _bio, label: 'About you', maxLines: 3),
            const SizedBox(height: AppSpacing.md),
            const Text('Speaking language', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in speakingLanguages.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _language == entry.key,
                    onSelected: (_) => setState(() => _language = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: _country, label: 'Country (e.g. IN)'),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              key: ValueKey(_gender),
              initialValue: _gender,
              decoration: const InputDecoration(labelText: 'Gender'),
              items: const [
                DropdownMenuItem(
                  value: 'UNSPECIFIED',
                  child: Text('Unspecified'),
                ),
                DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                DropdownMenuItem(value: 'MALE', child: Text('Male')),
                DropdownMenuItem(value: 'OTHER', child: Text('Other')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _gender = value);
                }
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Appear in discovery'),
              value: _discoverable,
              onChanged: (value) => setState(() => _discoverable = value),
            ),
            if (_localError != null ||
                (state.status == ProfileViewStatus.error &&
                    state.failure != null)) ...[
              Text(
                _localError ?? state.failure!.userMessage,
                style: const TextStyle(color: AppColors.danger),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            AppButton(
              label: 'Save changes',
              loading: state.saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
