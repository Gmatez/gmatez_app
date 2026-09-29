import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/di/core_providers.dart';
import '../../../../core/motion/app_motion.dart';
import '../../domain/validators/auth_validators.dart';
import '../state/auth_notifier.dart';
import '../state/auth_state.dart';
import '../widgets/auth_hero.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  String _dialCode = '+91';
  String? _localError;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = PhoneValidator.validateNational(_phone.text);
    setState(() => _localError = error);
    if (error != null) {
      return;
    }
    final e164 = PhoneValidator.toE164(_dialCode, _phone.text);
    final ok = await ref
        .read(authNotifierProvider.notifier)
        .requestPhoneOtp(e164);
    if (ok && mounted) {
      await context.push(AppRoutes.otp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final busy = auth.status == AuthStatus.authenticating;
    final failure = auth.failure;
    final error =
        _localError ??
        (failure?.code == 'VALIDATION_FAILED'
            ? 'Enter a valid 10-digit mobile number.'
            : failure?.userMessage);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.introGradient,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
            children: [
              const AuthHero(),
              FadeInUp(
                delay: const Duration(milliseconds: 80),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Sign in with your mobile number',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.figtree(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.32),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _dialCode,
                                dropdownColor: AppColors.primaryDim,
                                iconEnabledColor: Colors.white,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: '+91',
                                    child: Text('+91'),
                                  ),
                                  DropdownMenuItem(
                                    value: '+1',
                                    child: Text('+1'),
                                  ),
                                  DropdownMenuItem(
                                    value: '+44',
                                    child: Text('+44'),
                                  ),
                                ],
                                onChanged: busy
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setState(() => _dialCode = value);
                                        }
                                      },
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _phone,
                              enabled: !busy,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              cursorColor: AppColors.primary,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                                hintText: 'Phone number',
                                hintStyle: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: const BorderSide(
                                    color: Colors.white,
                                    width: 1.4,
                                  ),
                                ),
                              ),
                              onChanged: (_) {
                                if (_localError != null) {
                                  setState(() => _localError = null);
                                }
                              },
                              onSubmitted: (_) => _submit(),
                            ),
                          ),
                        ],
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFFFE4E6)),
                        ),
                        if (auth.failure?.kind.name == 'offline')
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'API ${ref.watch(appConfigProvider).apiBaseUrl}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: busy ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primaryDim,
                            shape: const StadiumBorder(),
                          ),
                          child: busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Continue',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_rounded),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
