import 'package:flutter_test/flutter_test.dart';
import 'package:gmatez_app/features/home/presentation/widgets/promo_banner_carousel.dart';

void main() {
  test('one banner uses the same width as the parent content', () {
    expect(promoBannerCardWidth(maxWidth: 360, count: 1), 360);
  });

  test('several banners stay inside the parent and still peek', () {
    final width = promoBannerCardWidth(maxWidth: 360, count: 3);
    expect(width, lessThan(360));
    expect(width, greaterThan(200));
  });
}
