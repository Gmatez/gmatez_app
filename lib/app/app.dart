import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_layout.dart';
import 'theme/app_theme.dart';
import '../features/calls/presentation/widgets/incoming_call_host.dart';

class GmatezApp extends ConsumerWidget {
  const GmatezApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Gmatez',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: appTextScaler(context)),
          child: IncomingCallHost(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
