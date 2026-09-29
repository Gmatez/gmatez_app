import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_layout.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/di/core_providers.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/state/auth_notifier.dart';

class HostCallSettingsScreen extends ConsumerStatefulWidget {
  const HostCallSettingsScreen({super.key});

  @override
  ConsumerState<HostCallSettingsScreen> createState() =>
      _HostCallSettingsScreenState();
}

class _HostCallSettingsScreenState
    extends ConsumerState<HostCallSettingsScreen> {
  final _languages = TextEditingController();
  final _interests = TextEditingController();
  final _bio = TextEditingController();
  final _voiceRate = TextEditingController();
  final _videoRate = TextEditingController();
  bool _voice = true;
  bool _video = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _languages.dispose();
    _interests.dispose();
    _bio.dispose();
    _voiceRate.dispose();
    _videoRate.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(apiClientProvider)
        .get(ApiPaths.hostsMe, parser: asMap);
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      switch (result) {
        case Failure(:final failure):
          _error = failure.userMessage;
        case Success(:final value):
          final host = asMap(value['host']);
          _voice = host['voiceEnabled'] as bool? ?? true;
          _video = host['videoEnabled'] as bool? ?? true;
          _voiceRate.text = '${asInt(host['voiceRatePerMinuteCents'], 100)}';
          _videoRate.text = '${asInt(host['videoRatePerMinuteCents'], 150)}';
          _languages.text = ((host['languages'] as List?) ?? const [])
              .whereType<String>()
              .join(', ');
          _interests.text = ((host['interests'] as List?) ?? const [])
              .whereType<String>()
              .join(', ');
          _bio.text = host['applicationBio'] as String? ?? '';
      }
    });
  }

  List<String> _csv(String raw) {
    return raw
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await ref
        .read(apiClientProvider)
        .patch(
          ApiPaths.hostsMe,
          body: {
            'voiceEnabled': _voice,
            'videoEnabled': _video,
            'voiceRatePerMinuteCents':
                int.tryParse(_voiceRate.text.trim()) ?? 100,
            'videoRatePerMinuteCents':
                int.tryParse(_videoRate.text.trim()) ?? 150,
            'languages': _csv(_languages.text),
            'interests': _csv(_interests.text),
            'applicationBio': _bio.text.trim(),
          },
          parser: (_) {},
        );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (result case Failure(:final failure)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.userMessage)));
      return;
    }
    await ref.read(authNotifierProvider.notifier).refreshUser();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Call settings saved.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MistScaffold(
      appBar: AppBar(title: const Text('Call settings')),
      body: AsyncBody(
        loading: _loading,
        error: _error,
        onRetry: _load,
        skeleton: const ScreenSkeleton.cards(),
        child: AppLayout.constrain(
          context,
          child: ListView(
            padding: AppLayout.pagePadding(context).copyWith(
              top: AppSpacing.sm,
              bottom: AppSpacing.xl,
            ),
            children: [
              const ScreenHeader(
                title: 'Rates & availability',
                subtitle:
                    'Rates and call types are validated by the backend. Discovery and incoming calls use these values.',
              ),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Voice calls'),
                      value: _voice,
                      onChanged: (value) => setState(() => _voice = value),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Video calls'),
                      value: _video,
                      onChanged: (value) => setState(() => _video = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SectionLabel('Pricing'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  children: [
                    AppTextField(
                      controller: _voiceRate,
                      label: 'Voice rate (cents/min)',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _videoRate,
                      label: 'Video rate (cents/min)',
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SectionLabel('Profile on Discover'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  children: [
                    AppTextField(
                      controller: _languages,
                      label: 'Languages (comma separated)',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _interests,
                      label: 'Interests (comma separated)',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(controller: _bio, label: 'Host bio'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: _saving ? 'Saving…' : 'Save settings',
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
