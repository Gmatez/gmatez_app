import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_layout.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/di/core_providers.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/app_widgets.dart';

class AdminConsoleScreen extends ConsumerStatefulWidget {
  const AdminConsoleScreen({super.key});

  @override
  ConsumerState<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends ConsumerState<AdminConsoleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, dynamic>? _overview;
  List<Map<String, dynamic>> _hosts = const [];
  List<Map<String, dynamic>> _payouts = const [];
  List<Map<String, dynamic>> _reports = const [];
  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _calls = const [];
  List<Map<String, dynamic>> _payments = const [];
  List<Map<String, dynamic>> _audit = const [];
  List<Map<String, dynamic>> _banners = const [];
  bool _loading = true;
  String? _error;

  ApiClient get _api => ref.read(apiClientProvider);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final overview = await _api.get(ApiPaths.adminOverview, parser: asMap);
    final hosts = await _api.get(ApiPaths.adminHosts, parser: asMapList);
    final payouts = await _api.get(ApiPaths.adminPayouts, parser: asMapList);
    final reports = await _api.get(ApiPaths.adminReports, parser: asMapList);
    final users = await _api.get(ApiPaths.adminUsers, parser: asMapList);
    final calls = await _api.get(ApiPaths.adminCalls, parser: asMapList);
    final payments = await _api.get(ApiPaths.adminPayments, parser: asMapList);
    final audit = await _api.get(ApiPaths.adminAuditLogs, parser: asMapList);
    final banners = await _api.get(ApiPaths.adminBanners, parser: asMapList);
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      if (overview case Failure(:final failure)) {
        _error = failure.userMessage;
      } else if (overview case Success(:final value)) {
        _overview = value;
      }
      if (hosts case Success(:final value)) {
        _hosts = value;
      }
      if (payouts case Success(:final value)) {
        _payouts = value;
      }
      if (reports case Success(:final value)) {
        _reports = value;
      }
      if (users case Success(:final value)) {
        _users = value;
      }
      if (calls case Success(:final value)) {
        _calls = value;
      }
      if (payments case Success(:final value)) {
        _payments = value;
      }
      if (audit case Success(:final value)) {
        _audit = value;
      }
      if (banners case Success(:final value)) {
        _banners = value;
      }
    });
  }

  Future<void> _createBanner() async {
    final titleCtrl = TextEditingController();
    final subtitleCtrl = TextEditingController();
    final linkCtrl = TextEditingController(text: AppRoutes.wallet);
    final ctaCtrl = TextEditingController(text: 'Learn more');
    String audience = 'ALL';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('New banner'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    TextField(
                      controller: subtitleCtrl,
                      decoration: const InputDecoration(labelText: 'Subtitle'),
                    ),
                    TextField(
                      controller: ctaCtrl,
                      decoration: const InputDecoration(labelText: 'CTA'),
                    ),
                    TextField(
                      controller: linkCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Deep link',
                        hintText: '/wallet',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: audience,
                      decoration: const InputDecoration(labelText: 'Audience'),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('ALL')),
                        DropdownMenuItem(value: 'USER', child: Text('USER')),
                        DropdownMenuItem(value: 'HOST', child: Text('HOST')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setLocal(() => audience = v);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true || !mounted) {
      return;
    }
    final title = titleCtrl.text.trim();
    if (title.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title required')));
      return;
    }
    final result = await _api.post(
      ApiPaths.adminBanners,
      body: {
        'title': title,
        'subtitle': subtitleCtrl.text.trim(),
        'ctaLabel': ctaCtrl.text.trim().isEmpty ? 'Learn more' : ctaCtrl.text.trim(),
        'deepLink': linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
        'audience': audience,
        'priority': 5,
        'isActive': true,
      },
      parser: asMap,
    );
    if (!mounted) {
      return;
    }
    final message = switch (result) {
      Failure(:final failure) => failure.userMessage,
      Success() => 'Banner created',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    await _load();
  }

  Future<void> _patch(
    String path, {
    required Object body,
    required String success,
  }) async {
    final result = await _api.patch(path, body: body, parser: (_) {});
    if (!mounted) {
      return;
    }
    final message = switch (result) {
      Failure(:final failure) => failure.userMessage,
      Success() => success,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return MistScaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          TextButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text('App'),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Hosts'),
            Tab(text: 'Calls'),
            Tab(text: 'Payments'),
            Tab(text: 'Payouts'),
            Tab(text: 'Reports'),
            Tab(text: 'Banners'),
          ],
        ),
      ),
      body: AsyncBody(
        loading: _loading,
        error: _error,
        onRetry: _load,
        skeleton: const ScreenSkeleton.cards(),
        animateChild: false,
        child: TabBarView(
          controller: _tabs,
          children: [
            RefreshIndicator(
              onRefresh: _load,
              child: AppLayout.constrain(
                context,
                child: ListView(
                padding: AppLayout.pagePadding(context).copyWith(
                  top: AppSpacing.lg,
                  bottom: AppSpacing.xl,
                ),
                children: [
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      _OverviewStat(
                        'Users',
                        '${_overview?['users'] ?? 0}',
                      ),
                      _OverviewStat(
                        'Calls',
                        '${_overview?['calls'] ?? 0}',
                      ),
                      _OverviewStat(
                        'Payments',
                        '${_overview?['succeededPayments'] ?? 0}',
                      ),
                      _OverviewStat(
                        'Pending hosts',
                        '${_overview?['pendingHosts'] ?? 0}',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionLabel('Users'),
                  const SizedBox(height: AppSpacing.sm),
                  ..._users.map((row) {
                    final id = row['id'] as String? ?? '';
                    final name =
                        asMap(row['profile'])['displayName'] ??
                        row['email'] ??
                        id;
                    return AppCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                      title: Text('$name · ${row['status']}'),
                      subtitle: Text('${row['email']} · ${row['role']}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (status) => _patch(
                          ApiPaths.adminUserStatus(id),
                          body: {'status': status},
                          success: 'User $status',
                        ),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'ACTIVE',
                            child: Text('Reactivate'),
                          ),
                          PopupMenuItem(
                            value: 'SUSPENDED',
                            child: Text('Suspend'),
                          ),
                          PopupMenuItem(value: 'DELETED', child: Text('Ban')),
                        ],
                      ),
                    ),
                    );
                  }),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionLabel('Audit'),
                  const SizedBox(height: AppSpacing.sm),
                  ..._audit.take(20).map((row) {
                    return AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${row['action']}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${row['targetType']}/${row['targetId']} · ${row['createdAt']}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
              ),
            ),
            RefreshIndicator(
              onRefresh: _load,
              child: AppLayout.constrain(
                context,
                child: ListView(
                padding: AppLayout.pagePadding(context).copyWith(
                  top: AppSpacing.lg,
                  bottom: AppSpacing.xl,
                ),
                children: _hosts.map((row) {
                  final user = asMap(row['user']);
                  final id = (row['userId'] ?? user['id']) as String? ?? '';
                  final name =
                      asMap(user['profile'])['displayName'] ??
                      user['email'] ??
                      id;
                  return AppCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      title: Text('$name · ${row['status']}'),
                      subtitle: Text(
                        '${user['email'] ?? ''} · ${row['availability'] ?? ''}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (status) => _patch(
                          ApiPaths.adminHostStatus(id),
                          body: {'status': status},
                          success: 'Host $status',
                        ),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'ACTIVE',
                            child: Text('Approve'),
                          ),
                          PopupMenuItem(
                            value: 'REJECTED',
                            child: Text('Reject'),
                          ),
                          PopupMenuItem(
                            value: 'SUSPENDED',
                            child: Text('Suspend'),
                          ),
                          PopupMenuItem(
                            value: 'PENDING_REVIEW',
                            child: Text('Reopen'),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              ),
            ),
            RefreshIndicator(
              onRefresh: _load,
              child: AppLayout.constrain(
                context,
                child: ListView(
                padding: AppLayout.pagePadding(context).copyWith(
                  top: AppSpacing.lg,
                  bottom: AppSpacing.xl,
                ),
                children: _calls.map((row) {
                  final id = row['id'] as String? ?? '';
                  return AppCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                    title: Text('${row['status']} · ${row['callType']}'),
                    subtitle: Text(
                      '${row['callerId']} → ${row['calleeId']} · ${formatCents(asInt(row['billedAmountCents']))}',
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        final result = await _api.post(
                          ApiPaths.adminCallRefund(id),
                          body: {'reason': 'admin_console'},
                          parser: (_) {},
                        );
                        if (!mounted) {
                          return;
                        }
                        final message = switch (result) {
                          Failure(:final failure) => failure.userMessage,
                          Success() => 'Refund queued',
                        };
                        ScaffoldMessenger.of(
                          this.context,
                        ).showSnackBar(SnackBar(content: Text(message)));
                        await _load();
                      },
                      child: const Text('Refund'),
                    ),
                  ),
                  );
                }).toList(),
              ),
              ),
            ),
            RefreshIndicator(
              onRefresh: _load,
              child: AppLayout.constrain(
                context,
                child: ListView(
                padding: AppLayout.pagePadding(context).copyWith(
                  top: AppSpacing.lg,
                  bottom: AppSpacing.xl,
                ),
                children: _payments.map((row) {
                  return AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${formatCents(asInt(row['amountCents']))} · ${row['status']}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${row['userId']} · ${row['providerPaymentId']}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              ),
            ),
            RefreshIndicator(
              onRefresh: _load,
              child: AppLayout.constrain(
                context,
                child: ListView(
                padding: AppLayout.pagePadding(context).copyWith(
                  top: AppSpacing.lg,
                  bottom: AppSpacing.xl,
                ),
                children: _payouts.map((row) {
                  final id = row['id'] as String? ?? '';
                  return AppCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                    title: Text(
                      '${formatCents(asInt(row['amountCents']))} · ${row['status']}',
                    ),
                    subtitle: Text('${row['userId']} · ${row['createdAt']}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (status) => _patch(
                        ApiPaths.adminPayout(id),
                        body: {'status': status},
                        success: 'Payout $status',
                      ),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'PROCESSING',
                          child: Text('Processing'),
                        ),
                        PopupMenuItem(
                          value: 'COMPLETED',
                          child: Text('Complete'),
                        ),
                        PopupMenuItem(value: 'FAILED', child: Text('Fail')),
                        PopupMenuItem(value: 'REJECTED', child: Text('Reject')),
                      ],
                    ),
                  ),
                  );
                }).toList(),
              ),
              ),
            ),
            RefreshIndicator(
              onRefresh: _load,
              child: AppLayout.constrain(
                context,
                child: ListView(
                padding: AppLayout.pagePadding(context).copyWith(
                  top: AppSpacing.lg,
                  bottom: AppSpacing.xl,
                ),
                children: _reports.map((row) {
                  final id = row['id'] as String? ?? '';
                  return AppCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                    title: Text('${row['reason']} · ${row['status']}'),
                    subtitle: Text(
                      '${row['reporterId']} → ${row['reportedId']}'
                      '${row['referenceType'] != null ? ' · ${row['referenceType']}/${row['referenceId']}' : ''}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (status) => _patch(
                        ApiPaths.adminReport(id),
                        body: {'status': status},
                        success: 'Report $status',
                      ),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'UNDER_REVIEW',
                          child: Text('Review'),
                        ),
                        PopupMenuItem(
                          value: 'RESOLVED',
                          child: Text('Resolve'),
                        ),
                        PopupMenuItem(
                          value: 'DISMISSED',
                          child: Text('Dismiss'),
                        ),
                      ],
                    ),
                  ),
                  );
                }).toList(),
              ),
              ),
            ),
            RefreshIndicator(
              onRefresh: _load,
              child: AppLayout.constrain(
                context,
                child: ListView(
                  padding: AppLayout.pagePadding(context).copyWith(
                    top: AppSpacing.lg,
                    bottom: AppSpacing.xl,
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _createBanner,
                        icon: const Icon(Icons.add),
                        label: const Text('New banner'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ..._banners.map((row) {
                      final id = row['id'] as String? ?? '';
                      final active = row['isActive'] == true;
                      return AppCard(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          title: Text('${row['title']} · ${row['audience']}'),
                          subtitle: Text(
                            '${row['subtitle'] ?? ''}\n'
                            '${row['ctaLabel'] ?? ''} → ${row['deepLink'] ?? '—'}'
                            ' · p${row['priority'] ?? 0}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: active,
                                onChanged: (v) => _patch(
                                  ApiPaths.adminBanner(id),
                                  body: {'isActive': v},
                                  success: v ? 'Banner on' : 'Banner off',
                                ),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () async {
                                  final result = await _api.delete(
                                    ApiPaths.adminBanner(id),
                                    parser: (_) {},
                                  );
                                  if (!mounted) {
                                    return;
                                  }
                                  final message = switch (result) {
                                    Failure(:final failure) =>
                                      failure.userMessage,
                                    Success() => 'Banner deleted',
                                  };
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                  await _load();
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
