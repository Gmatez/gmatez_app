import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import 'locale/locale_controller.dart';
import 'router/app_router.dart';
import 'theme/app_layout.dart';
import 'theme/app_theme.dart';
import '../features/calls/presentation/widgets/incoming_call_host.dart';

class GmatezApp extends ConsumerStatefulWidget {
  const GmatezApp({super.key});

  @override
  ConsumerState<GmatezApp> createState() => _GmatezAppState();
}

class _GmatezAppState extends ConsumerState<GmatezApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(localeControllerProvider.notifier).restore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeControllerProvider);
    return MaterialApp.router(
      title: 'Gmatez',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: AppStrings.supported,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
