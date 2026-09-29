import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
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
  final _language = TextEditingController();
  final _country = TextEditingController();
  final _avatar = TextEditingController();
  final _rate = TextEditingController();
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
    _language.dispose();
    _country.dispose();
    _avatar.dispose();
    _rate.dispose();
    super.dispose();
  }

  void _hydrate(UserProfile profile) {
    if (_hydrated) {
      return;
    }
    _hydrated = true;
    _name.text = profile.displayName;
    _bio.text = profile.bio;
    _language.text = profile.language ?? '';
    _country.text = profile.country ?? '';
    _avatar.text = profile.avatarUrl ?? '';
    _rate.text = '${profile.ratePerMinuteCents}';
    _gender = profile.gender;
    _discoverable = profile.isDiscoverable;
  }

  Future<void> _save() async {
    final error =
        ProfileValidators.displayName(_name.text) ??
        ProfileValidators.bio(_bio.text) ??
        ProfileValidators.language(_language.text) ??
        ProfileValidators.country(_country.text) ??
        ProfileValidators.avatarUrl(_avatar.text) ??
        ProfileValidators.ratePerMinuteCents(_rate.text);
    setState(() => _localError = error);
    if (error != null) {
      return;
    }
    final ok = await ref
        .read(myProfileNotifierProvider.notifier)
        .save(
          ProfileUpdate(
            displayName: _name.text.trim(),
            bio: _bio.text,
            language: _language.text.trim().isEmpty
                ? null
                : _language.text.trim().toLowerCase(),
            country: _country.text.trim().isEmpty
                ? null
                : _country.text.trim().toUpperCase(),
            avatarUrl: _avatar.text.trim(),
            gender: _gender,
            isDiscoverable: _discoverable,
            ratePerMinuteCents: int.tryParse(_rate.text.trim()),
          ),
        );
    if (ok && mounted) {
      ref.invalidate(discoveryNotifierProvider);
      context.pop();
    }
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

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.status == ProfileViewStatus.loading && profile == null)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: LinearProgressIndicator(),
              ),
            AppTextField(controller: _name, label: 'Display name'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: _bio, label: 'Bio'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: _language, label: 'Language (e.g. en)'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: _country, label: 'Country (e.g. US)'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: _avatar, label: 'Avatar URL'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _rate,
              label: 'Rate per minute (cents)',
              keyboardType: TextInputType.number,
            ),
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
