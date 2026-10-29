import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';



import '../../../../app/router/app_routes.dart';

import '../../../../app/theme/app_colors.dart';

import '../../../../app/locale/locale_controller.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../app/theme/app_layout.dart';

import '../../../../app/theme/app_tokens.dart';

import '../../../../core/constants/api_paths.dart';

import '../../../../core/di/core_providers.dart';

import '../../../../core/motion/app_motion.dart';

import '../../../../core/utils/result.dart';

import '../../../../core/widgets/app_widgets.dart';

import '../../../auth/presentation/state/auth_notifier.dart';



class SettingsScreen extends ConsumerStatefulWidget {

  const SettingsScreen({super.key});



  @override

  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();

}



class _SettingsScreenState extends ConsumerState<SettingsScreen> {

  List<Map<String, dynamic>> _blocks = const [];



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBlocks());

  }



  Future<void> _loadBlocks() async {

    final result = await ref

        .read(apiClientProvider)

        .get(

          ApiPaths.blocks,

          parser: (data) {

            if (data is List) {

              return data.whereType<Map<String, dynamic>>().toList();

            }

            if (data is Map<String, dynamic> && data['items'] is List) {

              return (data['items'] as List)

                  .whereType<Map<String, dynamic>>()

                  .toList();

            }

            return const <Map<String, dynamic>>[];

          },

        );

    if (!mounted) {

      return;

    }

    if (result case Success(:final value)) {

      setState(() => _blocks = value);

    }

  }



  @override

  Widget build(BuildContext context) {

    final user = ref.watch(authNotifierProvider).user;



    return MistScaffold(

      appBar: AppBar(title: const Text('Settings')),

      body: SafeArea(

        child: AppLayout.constrain(

          context,

          child: ListView(

            padding: AppLayout.pagePadding(context).copyWith(

              top: AppSpacing.sm,

              bottom: AppSpacing.xl,

            ),

            children: [

              ScreenHeader(

                title: AppStrings.of(context)('settings'),

                subtitle: AppStrings.of(context)('language'),

              ),

              const SizedBox(height: 12),

              _LanguagePicker(),

              FadeInUp(

                child: StaggeredList(

                  children: [

                    AppMenuTile(

                      icon: Icons.person_outline_rounded,

                      title: AppStrings.of(context)('editProfile'),

                      onTap: () => context.push(AppRoutes.editProfile),

                    ),

                    if (user?.isAdmin == true)

                      AppMenuTile(

                        icon: Icons.admin_panel_settings_outlined,

                        title: 'Admin console',

                        onTap: () => context.push(AppRoutes.admin),

                      ),

                    if (user?.isActiveHost == true) ...[

                      AppMenuTile(

                        icon: Icons.tune_rounded,

                        title: AppStrings.of(context)('callSettings'),

                        onTap: () => context.push(AppRoutes.hostCallSettings),

                      ),

                      AppMenuTile(

                        icon: Icons.payments_outlined,

                        title: AppStrings.of(context)('earnings'),

                        onTap: () => context.push(AppRoutes.earnings),

                      ),

                      AppMenuTile(

                        icon: Icons.account_balance_outlined,

                        title: AppStrings.of(context)('payouts'),

                        onTap: () => context.push(AppRoutes.payouts),

                      ),

                    ],

                  ],

                ),

              ),

              const Padding(

                padding: EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),

                child: SectionLabel('About Gmatez'),

              ),

              FadeInUp(

                delay: AppDurations.fast,

                child: StaggeredList(

                  children: [

                    AppCard(

                      child: Column(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: const [

                          Text(

                            'Help',

                            style: TextStyle(fontWeight: FontWeight.w800),

                          ),

                          SizedBox(height: AppSpacing.xs),

                          Text(

                            'Discover people, message, and start billed 1:1 calls. Wallet credits come from verified payments only.',

                            style: TextStyle(height: 1.4),

                          ),

                        ],

                      ),

                    ),

                    AppCard(

                      child: Column(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: const [

                          Text(

                            'Terms',

                            style: TextStyle(fontWeight: FontWeight.w800),

                          ),

                          SizedBox(height: AppSpacing.xs),

                          Text(

                            'Gmatez is a real-time calling platform. You are responsible for lawful use. Paid calls are billed by the backend from connected duration.',

                            style: TextStyle(height: 1.4),

                          ),

                        ],

                      ),

                    ),

                    AppCard(

                      child: Column(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: const [

                          Text(

                            'Privacy',

                            style: TextStyle(fontWeight: FontWeight.w800),

                          ),

                          SizedBox(height: AppSpacing.xs),

                          Text(

                            'Profile, call, and financial records are stored on the server. Deleted accounts are anonymized; ledgers are retained.',

                            style: TextStyle(height: 1.4),

                          ),

                        ],

                      ),

                    ),

                    if (user?.isActiveHost != true && user?.isPendingHost != true)

                    AppMenuTile(

                      icon: Icons.headset_mic_outlined,

                      title: AppStrings.of(context)('becomeHost'),

                      subtitle: AppStrings.of(context)('becomeHostSubtitle'),

                      onTap: () => context.push(AppRoutes.hostApply),

                    ),

                  ],

                ),

              ),

              const Padding(

                padding: EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),

                child: SectionLabel('Blocked users'),

              ),

              if (_blocks.isEmpty)

                const AppCard(

                  child: Text(

                    'No blocked users.',

                    style: TextStyle(color: AppColors.textSecondary),

                  ),

                )

              else

                ..._blocks.map((row) {

                  final id =

                      (row['blockedId'] ?? row['userId'] ?? row['id'])

                          as String?;

                  return AppCard(

                    padding: EdgeInsets.zero,

                    child: ListTile(

                      title: Text(

                        id ?? 'User',

                        maxLines: 1,

                        overflow: TextOverflow.ellipsis,

                      ),

                      trailing: TextButton(

                        onPressed: id == null

                            ? null

                            : () async {

                                await ref

                                    .read(apiClientProvider)

                                    .delete(ApiPaths.unblock(id), parser: (_) {});

                                await _loadBlocks();

                              },

                        child: const Text('Unblock'),

                      ),

                    ),

                  );

                }),

              const SizedBox(height: AppSpacing.lg),

              if (user?.host == null || user?.host?.status == 'REJECTED')

                AppButton(

                  label: AppStrings.of(context)('becomeHost'),

                  onPressed: () => context.push(AppRoutes.hostApply),

                ),

              if (user?.isPendingHost == true)

                AppButton(

                  label: AppStrings.of(context)('hostStatus'),

                  variant: AppButtonVariant.secondary,

                  onPressed: () => context.go(AppRoutes.hostPending),

                ),

              AppButton(

                label: AppStrings.of(context)('logOut'),

                variant: AppButtonVariant.ghost,

                onPressed: () =>

                    ref.read(authNotifierProvider.notifier).logout(),

              ),

              const SizedBox(height: AppSpacing.sm),

              AppButton(

                label: 'Delete account',

                variant: AppButtonVariant.danger,

                onPressed: () async {

                  final confirmed = await showDialog<bool>(

                    context: context,

                    builder: (context) => AlertDialog(

                      title: const Text('Delete account?'),

                      content: const Text(

                        'This deactivates your account, revokes sessions, and anonymizes your profile. Financial records are retained.',

                      ),

                      actions: [

                        TextButton(

                          onPressed: () => Navigator.pop(context, false),

                          child: const Text('Cancel'),

                        ),

                        FilledButton(

                          onPressed: () => Navigator.pop(context, true),

                          child: const Text('Delete'),

                        ),

                      ],

                    ),

                  );

                  if (confirmed != true || !context.mounted) {

                    return;

                  }

                  final result = await ref

                      .read(apiClientProvider)

                      .delete(ApiPaths.usersMeDelete, parser: (_) {});

                  if (!context.mounted) {

                    return;

                  }

                  if (result case Failure(:final failure)) {

                    ScaffoldMessenger.of(

                      context,

                    ).showSnackBar(SnackBar(content: Text(failure.userMessage)));

                    return;

                  }

                  await ref.read(authNotifierProvider.notifier).logout();

                },

              ),

            ],

          ),

        ),

      ),

    );

  }

}



class _LanguagePicker extends ConsumerWidget {

  const _LanguagePicker();



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final selected = ref.watch(localeControllerProvider).languageCode;

    return Wrap(

      spacing: 8,

      runSpacing: 8,

      children: [

        for (final entry in AppStrings.languageNames.entries)

          ChoiceChip(

            label: Text(entry.value),

            selected: selected == entry.key,

            onSelected: (_) {

              ref.read(localeControllerProvider.notifier).setLanguage(entry.key);

            },

          ),

      ],

    );

  }

}


