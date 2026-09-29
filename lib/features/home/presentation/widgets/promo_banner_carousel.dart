import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/motion/app_motion.dart';

class PromoBanner {
  const PromoBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    this.imageUrl,
    this.deepLink,
  });

  final String id;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final String? imageUrl;
  final String? deepLink;

  factory PromoBanner.fromJson(Map<String, dynamic> json) {
    return PromoBanner(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      ctaLabel: json['ctaLabel'] as String? ?? 'Learn more',
      imageUrl: json['imageUrl'] as String?,
      deepLink: json['deepLink'] as String?,
    );
  }
}

/// Horizontal promo strip for the home screen (safe inside a vertical ListView).
class PromoBannerCarousel extends StatefulWidget {
  const PromoBannerCarousel({super.key, required this.banners});

  final List<PromoBanner> banners;

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel> {
  final _controller = ScrollController();
  int _index = 0;

  static const _cardHeight = 148.0;
  static const _gap = 10.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(PromoBanner banner) {
    final link = banner.deepLink?.trim();
    if (link == null || link.isEmpty) {
      return;
    }
    context.push(link);
  }

  double _cardWidth(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width;
    return (maxW * 0.82).clamp(260.0, 360.0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return const SizedBox.shrink();
    }

    final cardW = _cardWidth(context);
    final showDots = widget.banners.length > 1;

    return FadeInUp(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _cardHeight,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollUpdateNotification ||
                    n is ScrollEndNotification) {
                  final next = (n.metrics.pixels / (cardW + _gap))
                      .round()
                      .clamp(0, widget.banners.length - 1);
                  if (next != _index) {
                    setState(() => _index = next);
                  }
                }
                return false;
              },
              child: ListView.separated(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: widget.banners.length,
                separatorBuilder: (_, _) => const SizedBox(width: _gap),
                itemBuilder: (context, i) {
                  final banner = widget.banners[i];
                  return SizedBox(
                    width: cardW,
                    height: _cardHeight,
                    child: _BannerCard(
                      banner: banner,
                      onTap: () => _open(banner),
                    ),
                  );
                },
              ),
            ),
          ),
          if (showDots) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.banners.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: AppDurations.fast,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary
                        : AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner, required this.onTap});

  final PromoBanner banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        banner.imageUrl != null && banner.imageUrl!.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            gradient: hasImage
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppColors.creditGradient,
                  ),
            image: hasImage
                ? DecorationImage(
                    image: CachedNetworkImageProvider(banner.imageUrl!),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withValues(alpha: 0.35),
                      BlendMode.darken,
                    ),
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  banner.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.figtree(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                if (banner.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    banner.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.figtree(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
                const Spacer(),
                if (banner.deepLink != null && banner.deepLink!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      banner.ctaLabel,
                      style: GoogleFonts.figtree(
                        color: AppColors.primaryDim,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
