import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_layout.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/di/core_providers.dart';
import '../../../../core/motion/app_motion.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/state/auth_notifier.dart';
import '../../../discovery/presentation/state/discovery_notifier.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/presentation/state/profile_notifier.dart';
import '../state/host_onboarding_notifier.dart';

class HostOnboardingScreen extends ConsumerStatefulWidget {
  const HostOnboardingScreen({super.key});

  @override
  ConsumerState<HostOnboardingScreen> createState() =>
      _HostOnboardingScreenState();
}

class _HostOnboardingScreenState extends ConsumerState<HostOnboardingScreen> {
  late final PageController _pages = PageController();
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _language = TextEditingController(text: 'en');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(hostOnboardingProvider.notifier).restoreDraft();
      await ref.read(myProfileNotifierProvider.notifier).load();
      final profile = ref.read(myProfileNotifierProvider).profile;
      final user = ref.read(authNotifierProvider).user;
      final draft = ref.read(hostOnboardingProvider);
      ref
          .read(hostOnboardingProvider.notifier)
          .hydrate(
            displayName: draft.displayName.isNotEmpty
                ? draft.displayName
                : (profile?.displayName ?? user?.displayName),
            gender: draft.gender != 'UNSPECIFIED'
                ? draft.gender
                : profile?.gender,
            language: draft.language.isNotEmpty
                ? draft.language
                : profile?.language,
          );
      _name.text = ref.read(hostOnboardingProvider).displayName;
      _bio.text = ref.read(hostOnboardingProvider).bio;
      _language.text = ref.read(hostOnboardingProvider).language;
      final step = ref.read(hostOnboardingProvider).step;
      if (step > 0 && _pages.hasClients) {
        _pages.jumpToPage(step);
      }
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    _bio.dispose();
    _language.dispose();
    super.dispose();
  }

  HostOnboardingNotifier get _draft =>
      ref.read(hostOnboardingProvider.notifier);

  void _syncDraftFromFields() {
    _draft.patch(
      ref
          .read(hostOnboardingProvider)
          .copyWith(
            displayName: _name.text.trim(),
            bio: _bio.text.trim(),
            language: hostLanguageCode(_language.text),
          ),
    );
  }

  String? _stepError(int fromStep, HostOnboardingState draft) {
    switch (fromStep) {
      case 0:
        if (draft.displayName.trim().length < 2) {
          return 'Enter your full name (at least 2 characters).';
        }
        if (draft.bio.trim().length < 8) {
          return 'Tell us how you host (at least 8 characters).';
        }
        return null;
      case 1:
        if (draft.languages.isEmpty) {
          return 'Select at least one speaking language.';
        }
        if (draft.interests.isEmpty) {
          return 'Select at least one interest.';
        }
        return null;
      case 2:
        if (!draft.voiceEnabled && !draft.videoEnabled) {
          return 'Enable voice or video calls.';
        }
        return null;
      default:
        return null;
    }
  }

  void _go(int step) {
    _syncDraftFromFields();
    final draft = ref.read(hostOnboardingProvider);
    if (step > draft.step) {
      final error = _stepError(draft.step, draft);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(error),
          ),
        );
        return;
      }
    }
    _draft.setStep(step);
    _pages.animateToPage(
      step,
      duration: AppDurations.normal,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _submit() async {
    _syncDraftFromFields();
    final draft = ref.read(hostOnboardingProvider);
    if (!draft.canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          content: Text(
            'Please finish your profile, languages, interests, rates, and agreements before submitting.',
            softWrap: true,
            style: GoogleFonts.plusJakartaSans(height: 1.35),
          ),
        ),
      );
      return;
    }
    if (!draft.voiceEnabled && !draft.videoEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable voice or video calls.')),
      );
      return;
    }

    setState(() => _saving = true);
    final languageCode = hostLanguageCode(
      draft.languages.isNotEmpty ? draft.languages.first : draft.language,
    );
    final bio = draft.bio.trim();
    final profileResult = await ref
        .read(profileRepositoryProvider)
        .updateMine(
          ProfileUpdate(
            displayName: draft.displayName.trim().clampLength(40),
            bio: bio.length > 280 ? bio.substring(0, 280) : bio,
            gender: draft.gender,
            language: languageCode,
          ),
        );
    if (!mounted) {
      return;
    }
    if (profileResult case Failure(:final failure)) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.userMessage)),
      );
      return;
    }

    final languageCodes = draft.languages
        .map(hostLanguageCode)
        .toSet()
        .toList();
    final interestSlugs = draft.interests
        .map(hostInterestSlug)
        .where((value) => value.length >= 2)
        .toSet()
        .toList();

    final result = await ref
        .read(apiClientProvider)
        .post(
          ApiPaths.hostsApply,
          body: {
            'applicationBio': draft.bio.trim(),
            'languages': languageCodes,
            'interests': interestSlugs,
            'voiceEnabled': draft.voiceEnabled,
            'videoEnabled': draft.videoEnabled,
            'voiceRatePerMinuteCents': draft.voiceRatePerMinuteCents,
            'videoRatePerMinuteCents': draft.videoRatePerMinuteCents,
            'acceptedAgreements': const [
              {'agreementType': 'HOST_GUIDELINES', 'version': '1.0'},
              {'agreementType': 'TERMS_OF_SERVICE', 'version': '1.0'},
              {'agreementType': 'PRIVACY_POLICY', 'version': '1.0'},
            ],
          },
          parser: (_) {},
        );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (result case Failure(:final failure)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(failure.userMessage),
        ),
      );
      return;
    }
    await ref.read(hostOnboardingProvider.notifier).clearDraft();
    await ref.read(authNotifierProvider.notifier).refreshUser();
    if (mounted) {
      context.go(AppRoutes.hostPending);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(hostOnboardingProvider);
    return MistScaffold(
      appBar: AppBar(
        title: Text('Step ${draft.step + 1} of 4'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (draft.step == 0) {
              context.pop();
            } else {
              _go(draft.step - 1);
            }
          },
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: AppLayout.pagePadding(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (draft.step + 1) / 4,
                minHeight: 6,
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceMuted,
              ),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: _draft.setStep,
              children: [
                _PersonalStep(
                  name: _name,
                  bio: _bio,
                  language: _language,
                  draft: draft,
                  onChanged: _draft.patch,
                ),
                _LanguagesStep(draft: draft, notifier: _draft),
                const _VerificationStep(),
                _AgreementStep(draft: draft, onChanged: _draft.patch),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: AppLayout.pagePadding(context).copyWith(
                top: 8,
                bottom: 16,
              ),
              child: AppLayout.constrain(
                context,
                child: Row(
                children: [
                  if (draft.step > 0)
                    Expanded(
                      child: AppButton(
                        label: 'Back',
                        variant: AppButtonVariant.ghost,
                        onPressed: () => _go(draft.step - 1),
                      ),
                    ),
                  if (draft.step > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: draft.step == 3
                          ? (_saving ? 'Submitting…' : 'Submit Application')
                          : 'Continue',
                      loading: _saving,
                      onPressed: draft.step == 3
                          ? _submit
                          : () => _go(draft.step + 1),
                    ),
                  ),
                ],
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalStep extends StatelessWidget {
  const _PersonalStep({
    required this.name,
    required this.bio,
    required this.language,
    required this.draft,
    required this.onChanged,
  });

  final TextEditingController name;
  final TextEditingController bio;
  final TextEditingController language;
  final HostOnboardingState draft;
  final ValueChanged<HostOnboardingState> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppLayout.pagePadding(context).copyWith(
        top: AppSpacing.lg,
        bottom: AppSpacing.lg,
      ),
      children: [
        const FadeInUp(
          child: ScreenHeader(
            title: 'Personal Information',
            subtitle:
                'These fields update your Gmatez profile. Only values the backend accepts are saved.',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FadeInUp(
          delay: const Duration(milliseconds: 80),
          child: AppTextField(
            controller: name,
            label: 'Full name *',
            onChanged: (value) =>
                onChanged(draft.copyWith(displayName: value, bio: bio.text)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FadeInUp(
          delay: const Duration(milliseconds: 120),
          child: AppTextField(
            controller: bio,
            label: 'How you host *',
            maxLines: 4,
            onChanged: (value) =>
                onChanged(draft.copyWith(bio: value, displayName: name.text)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: draft.gender,
          decoration: const InputDecoration(labelText: 'Gender'),
          items: const [
            DropdownMenuItem(
              value: 'UNSPECIFIED',
              child: Text('Prefer not to say'),
            ),
            DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
            DropdownMenuItem(value: 'MALE', child: Text('Male')),
            DropdownMenuItem(value: 'OTHER', child: Text('Other')),
          ],
          onChanged: (value) {
            if (value != null) {
              onChanged(
                draft.copyWith(
                  gender: value,
                  displayName: name.text,
                  bio: bio.text,
                ),
              );
            }
          },
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: _languageDropdownValue(draft.language),
          decoration: const InputDecoration(labelText: 'Primary language'),
          items: [
            for (final entry in kHostLanguageCodes.entries)
              DropdownMenuItem(
                value: entry.value,
                child: Text(entry.key),
              ),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            language.text = value;
            onChanged(
              draft.copyWith(
                language: value,
                displayName: name.text,
                bio: bio.text,
              ),
            );
          },
        ),
      ],
    );
  }

  static String _languageDropdownValue(String raw) {
    final code = hostLanguageCode(raw);
    if (kHostLanguageCodes.containsValue(code)) {
      return code;
    }
    return 'en';
  }
}

class _LanguagesStep extends StatelessWidget {
  const _LanguagesStep({required this.draft, required this.notifier});

  final HostOnboardingState draft;
  final HostOnboardingNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppLayout.pagePadding(context).copyWith(
        top: AppSpacing.lg,
        bottom: AppSpacing.lg,
      ),
      children: [
        const ScreenHeader(title: 'Languages & Interests'),
        const SizedBox(height: AppSpacing.lg),
        const SectionLabel('Speaking languages *'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kHostLanguages
              .map(
                (item) => SoftChip(
                  label: item,
                  selected: draft.languages.contains(item),
                  onSelected: (_) => notifier.toggleLanguage(item),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionLabel('Interests *'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kHostInterests
              .map(
                (item) => SoftChip(
                  label: item,
                  selected: draft.interests.contains(item),
                  onSelected: (_) => notifier.toggleInterest(item),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _VerificationStep extends ConsumerWidget {
  const _VerificationStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(hostOnboardingProvider);
    final notifier = ref.read(hostOnboardingProvider.notifier);
    return ListView(
      padding: AppLayout.pagePadding(context).copyWith(
        top: AppSpacing.lg,
        bottom: AppSpacing.lg,
      ),
      children: [
        const ScreenHeader(
          title: 'Rates & call types',
          subtitle:
              'Set what callers pay per minute. Admin review is required before you go live. No identity documents are uploaded in this app.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: EdgeInsets.zero,
          child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Offer voice calls'),
          value: draft.voiceEnabled,
          onChanged: (value) =>
              notifier.patch(draft.copyWith(voiceEnabled: value)),
          ),
        ),
        if (draft.voiceEnabled)
          Padding(
            padding: AppLayout.pagePadding(context).copyWith(top: 0),
            child: _RatePicker(
              label: 'Voice rate',
              valueCents: draft.voiceRatePerMinuteCents,
              onChanged: (value) => notifier.patch(
                draft.copyWith(voiceRatePerMinuteCents: value),
              ),
            ),
          ),
        AppCard(
          padding: EdgeInsets.zero,
          child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Offer video calls'),
          value: draft.videoEnabled,
          onChanged: (value) =>
              notifier.patch(draft.copyWith(videoEnabled: value)),
          ),
        ),
        if (draft.videoEnabled)
          Padding(
            padding: AppLayout.pagePadding(context).copyWith(top: 0),
            child: _RatePicker(
              label: 'Video rate',
              valueCents: draft.videoRatePerMinuteCents,
              onChanged: (value) => notifier.patch(
                draft.copyWith(videoRatePerMinuteCents: value),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: EdgeInsets.zero,
          child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('I understand applications are reviewed by admin'),
          value: draft.verificationAcknowledged,
          onChanged: (value) =>
              notifier.patch(draft.copyWith(verificationAcknowledged: value)),
          ),
        ),
      ],
    );
  }
}

class _RatePicker extends StatelessWidget {
  const _RatePicker({
    required this.label,
    required this.valueCents,
    required this.onChanged,
  });

  final String label;
  final int valueCents;
  final ValueChanged<int> onChanged;

  static const _options = [50, 80, 100, 150, 200, 300];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label · ${(valueCents / 10).round()} credits/min',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _options
                .map(
                  (cents) => SoftChip(
                    label: '${(cents / 10).round()} cr',
                    selected: valueCents == cents,
                    onSelected: (_) => onChanged(cents),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AgreementStep extends StatelessWidget {
  const _AgreementStep({required this.draft, required this.onChanged});

  final HostOnboardingState draft;
  final ValueChanged<HostOnboardingState> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppLayout.pagePadding(context).copyWith(
        top: AppSpacing.lg,
        bottom: AppSpacing.lg,
      ),
      children: [
        const ScreenHeader(
          title: 'Agreement',
          subtitle: 'Confirm the policies below to submit your application.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            children: [
        _Check(
          label: 'Listener Agreement',
          value: draft.agreementAccepted,
          onChanged: (value) =>
              onChanged(draft.copyWith(agreementAccepted: value)),
        ),
        _Check(
          label: 'Community Guidelines',
          value: draft.guidelinesAccepted,
          onChanged: (value) =>
              onChanged(draft.copyWith(guidelinesAccepted: value)),
        ),
        _Check(
          label: 'Terms & Conditions',
          value: draft.termsAccepted,
          onChanged: (value) => onChanged(draft.copyWith(termsAccepted: value)),
        ),
        _Check(
          label: 'Privacy Policy',
          value: draft.privacyAccepted,
          onChanged: (value) =>
              onChanged(draft.copyWith(privacyAccepted: value)),
        ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: (next) => onChanged(next ?? false),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppColors.primary,
    );
  }
}
