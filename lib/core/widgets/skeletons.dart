import 'package:flutter/material.dart';

import '../../app/theme/app_layout.dart';
import '../../app/theme/app_tokens.dart';
import '../motion/app_motion.dart';

/// Circular shimmer used for avatars.
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ShimmerBox(
      width: size,
      height: size,
      borderRadius: size / 2,
    );
  }
}

/// Short text-line placeholder.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({
    super.key,
    this.width,
    this.height = 12,
  });

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ShimmerBox(
      width: width,
      height: height,
      borderRadius: AppRadii.xs,
    );
  }
}

/// List-row placeholder (avatar + two lines).
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final h = dense ? 64.0 : 76.0;
    return SizedBox(
      height: h,
      child: Row(
        children: [
          SkeletonCircle(size: dense ? 40 : 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SkeletonLine(width: MediaQuery.sizeOf(context).width * 0.42),
                const SizedBox(height: 8),
                const SkeletonLine(width: 140, height: 10),
              ],
            ),
          ),
          const SkeletonLine(width: 36, height: 10),
        ],
      ),
    );
  }
}

enum ScreenSkeletonKind {
  list,
  feed,
  profile,
  wallet,
  chat,
  dashboard,
  cards,
  home,
}

/// Screen-level skeleton used by [AsyncBody] and feature screens.
class ScreenSkeleton extends StatelessWidget {
  const ScreenSkeleton({
    super.key,
    this.kind = ScreenSkeletonKind.list,
    this.padding,
  });

  const ScreenSkeleton.list({super.key, this.padding})
      : kind = ScreenSkeletonKind.list;

  const ScreenSkeleton.feed({super.key, this.padding})
      : kind = ScreenSkeletonKind.feed;

  const ScreenSkeleton.profile({super.key, this.padding})
      : kind = ScreenSkeletonKind.profile;

  const ScreenSkeleton.wallet({super.key, this.padding})
      : kind = ScreenSkeletonKind.wallet;

  const ScreenSkeleton.chat({super.key, this.padding})
      : kind = ScreenSkeletonKind.chat;

  const ScreenSkeleton.dashboard({super.key, this.padding})
      : kind = ScreenSkeletonKind.dashboard;

  const ScreenSkeleton.cards({super.key, this.padding})
      : kind = ScreenSkeletonKind.cards;

  const ScreenSkeleton.home({super.key, this.padding})
      : kind = ScreenSkeletonKind.home;

  final ScreenSkeletonKind kind;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final pad = padding ??
        AppLayout.pagePadding(context).copyWith(
          top: AppSpacing.md,
          bottom: AppSpacing.xl,
        );

    return FadeInUp(
      duration: AppDurations.fast,
      child: switch (kind) {
        ScreenSkeletonKind.list => _ListSkeleton(padding: pad),
        ScreenSkeletonKind.feed => _FeedSkeleton(padding: pad),
        ScreenSkeletonKind.profile => _ProfileSkeleton(padding: pad),
        ScreenSkeletonKind.wallet => _WalletSkeleton(padding: pad),
        ScreenSkeletonKind.chat => _ChatSkeleton(padding: pad),
        ScreenSkeletonKind.dashboard => _DashboardSkeleton(padding: pad),
        ScreenSkeletonKind.cards => _CardsSkeleton(padding: pad),
        ScreenSkeletonKind.home => _HomeSkeleton(padding: pad),
      },
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton({required this.padding});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: 7,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => FadeInUp(
        delay: Duration(milliseconds: 40 * i),
        child: const SkeletonListTile(),
      ),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton({required this.padding});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => FadeInUp(
        delay: Duration(milliseconds: 50 * i),
        child: const ShimmerBox(height: 148),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton({required this.padding});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      children: [
        const Center(child: SkeletonCircle(size: 96)),
        const SizedBox(height: 16),
        const Center(child: SkeletonLine(width: 160, height: 18)),
        const SizedBox(height: 8),
        const Center(child: SkeletonLine(width: 120, height: 12)),
        const SizedBox(height: 24),
        const ShimmerBox(height: 88),
        const SizedBox(height: 12),
        const ShimmerBox(height: 56),
        const SizedBox(height: 12),
        const ShimmerBox(height: 56),
        const SizedBox(height: 12),
        const ShimmerBox(height: 56),
      ],
    );
  }
}

class _WalletSkeleton extends StatelessWidget {
  const _WalletSkeleton({required this.padding});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      children: [
        FadeInUp(child: const ShimmerBox(height: 140)),
        const SizedBox(height: 16),
        FadeInUp(
          delay: const Duration(milliseconds: 60),
          child: const SkeletonLine(width: 120, height: 14),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FadeInUp(
              delay: Duration(milliseconds: 80 + i * 50),
              child: const ShimmerBox(height: 72),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FadeInUp(
          delay: const Duration(milliseconds: 240),
          child: const SkeletonLine(width: 100, height: 14),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          4,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FadeInUp(
              delay: Duration(milliseconds: 280 + i * 40),
              child: const SkeletonListTile(dense: true),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatSkeleton extends StatelessWidget {
  const _ChatSkeleton({required this.padding});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FadeInUp(
            child: ShimmerBox(
              width: MediaQuery.sizeOf(context).width * 0.55,
              height: 44,
              borderRadius: AppRadii.sm,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FadeInUp(
            delay: const Duration(milliseconds: 60),
            child: ShimmerBox(
              width: MediaQuery.sizeOf(context).width * 0.48,
              height: 44,
              borderRadius: AppRadii.sm,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FadeInUp(
            delay: const Duration(milliseconds: 120),
            child: ShimmerBox(
              width: MediaQuery.sizeOf(context).width * 0.62,
              height: 64,
              borderRadius: AppRadii.sm,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FadeInUp(
            delay: const Duration(milliseconds: 180),
            child: ShimmerBox(
              width: MediaQuery.sizeOf(context).width * 0.4,
              height: 44,
              borderRadius: AppRadii.sm,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton({required this.padding});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      children: [
        const ShimmerBox(height: 120),
        const SizedBox(height: 14),
        Row(
          children: const [
            Expanded(child: ShimmerBox(height: 88)),
            SizedBox(width: 10),
            Expanded(child: ShimmerBox(height: 88)),
          ],
        ),
        const SizedBox(height: 14),
        const SkeletonLine(width: 120, height: 14),
        const SizedBox(height: 10),
        const SkeletonListTile(),
        const SizedBox(height: 10),
        const SkeletonListTile(),
        const SizedBox(height: 10),
        const SkeletonListTile(),
      ],
    );
  }
}

class _CardsSkeleton extends StatelessWidget {
  const _CardsSkeleton({required this.padding});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      children: [
        const SkeletonLine(width: 140, height: 16),
        const SizedBox(height: 14),
        ...List.generate(
          5,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FadeInUp(
              delay: Duration(milliseconds: 45 * i),
              child: const ShimmerBox(height: 84),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton({required this.padding});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInUp(child: const SkeletonLine(width: 180, height: 22)),
          const SizedBox(height: 8),
          FadeInUp(
            delay: const Duration(milliseconds: 40),
            child: const SkeletonLine(width: 240, height: 12),
          ),
          const SizedBox(height: 16),
          FadeInUp(
            delay: const Duration(milliseconds: 80),
            child: const ShimmerBox(height: 132),
          ),
          const SizedBox(height: 16),
          FadeInUp(
            delay: const Duration(milliseconds: 120),
            child: const ShimmerBox(height: 110),
          ),
          const SizedBox(height: 14),
          FadeInUp(
            delay: const Duration(milliseconds: 160),
            child: Row(
              children: const [
                Expanded(child: ShimmerBox(height: 72)),
                SizedBox(width: 10),
                Expanded(child: ShimmerBox(height: 72)),
                SizedBox(width: 10),
                Expanded(child: ShimmerBox(height: 72)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: const SkeletonLine(width: 130, height: 14),
          ),
          const SizedBox(height: 10),
          FadeInUp(
            delay: const Duration(milliseconds: 240),
            child: const SkeletonListTile(),
          ),
          const SizedBox(height: 10),
          FadeInUp(
            delay: const Duration(milliseconds: 280),
            child: const SkeletonListTile(),
          ),
        ],
      ),
    );
  }
}
