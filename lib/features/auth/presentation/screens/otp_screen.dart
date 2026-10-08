import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/motion/app_motion.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/validators/auth_validators.dart';
import '../state/auth_notifier.dart';
import '../state/auth_state.dart';
import '../widgets/auth_hero.dart';

Future<void> showPhoneOtpSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: const OtpScreen(asSheet: true),
      );
    },
  );
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, this.asSheet = false});

  final bool asSheet;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otp = TextEditingController();
  final _focus = FocusNode();
  String? _localError;
  int _secondsLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authNotifierProvider);
    final cooldown =
        auth.otpResendAvailableInSeconds ?? auth.otpExpiresInSeconds ?? 60;
    _secondsLeft = cooldown.clamp(1, 600);
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otp.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = OtpValidator.validate(_otp.text);
    setState(() => _localError = error);
    if (error != null) {
      return;
    }
    final ok = await ref
        .read(authNotifierProvider.notifier)
        .verifyPhoneOtp(_otp.text);
    if (ok && mounted && widget.asSheet) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _resend() async {
    final phone = ref.read(authNotifierProvider).pendingPhone;
    if (phone == null) {
      return;
    }
    final ok = await ref
        .read(authNotifierProvider.notifier)
        .requestPhoneOtp(phone);
    if (ok && mounted) {
      final auth = ref.read(authNotifierProvider);
      setState(() {
        _secondsLeft = (auth.otpResendAvailableInSeconds ?? 60).clamp(1, 600);
        _localError = null;
      });
      _startTimer();
    } else if (mounted) {
      final failure = ref.read(authNotifierProvider).failure;
      final retry = failure?.retryAfterSeconds;
      if (retry != null && retry > 0) {
        setState(() => _secondsLeft = retry);
        _startTimer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final busy = auth.status == AuthStatus.authenticating;
    final error = _localError ?? auth.failure?.userMessage;
    final code = _otp.text;
    final phone = formatPhone(auth.pendingPhone);

    final panel = Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadii.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: FadeInUp(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Enter verification code',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text.rich(
                  TextSpan(
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: 'We sent a 6-digit code to '),
                      TextSpan(
                        text: phone,
                        style: const TextStyle(
                          color: AppColors.primaryDim,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                // Real input is Offstage so Material underline/cursor
                // never paints under the digit boxes.
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Offstage(
                      offstage: true,
                      child: TextField(
                        controller: _otp,
                        focusNode: _focus,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        enableSuggestions: false,
                        showCursor: false,
                        style: const TextStyle(
                          color: Colors.transparent,
                          fontSize: 1,
                          height: 0.01,
                        ),
                        cursorColor: Colors.transparent,
                        decoration: const InputDecoration.collapsed(
                          hintText: '',
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        onChanged: (value) {
                          setState(() {});
                          if (value.length == 6 && !busy) {
                            _submit();
                          }
                        },
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _focus.requestFocus(),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const gap = 8.0;
                          final boxW = ((constraints.maxWidth - gap * 5) / 6)
                              .clamp(40.0, 52.0);
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(6, (index) {
                              final char = index < code.length
                                  ? code[index]
                                  : '';
                              final selected = code.length == index;
                              final filled = char.isNotEmpty;
                              return AnimatedContainer(
                                duration: AppDurations.fast,
                                width: boxW,
                                height: 56,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: filled
                                      ? AppColors.surfaceMuted
                                      : AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.border,
                                    width: selected ? 2 : 1.2,
                                  ),
                                ),
                                child: Text(
                                  char,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    height: 1,
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Text(
                      error,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: busy ? 'Verifying…' : 'Verify & continue',
                  loading: busy,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Flexible(
                      child: TextButton.icon(
                        onPressed: busy
                            ? null
                            : () {
                                if (widget.asSheet) {
                                  Navigator.of(context).pop();
                                } else {
                                  context.pop();
                                }
                              },
                        icon: const Icon(Icons.arrow_back_ios, size: 18),
                        label: const Text('Change number'),
                      ),
                    ),
                    TextButton(
                      onPressed: busy || _secondsLeft > 0 ? null : _resend,
                      child: Text(
                        _secondsLeft > 0
                            ? 'Resend in ${_secondsLeft}s'
                            : 'Resend code',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.asSheet) {
      return panel;
    }

    return Scaffold(
      body: GradientBackdrop(
        child: Column(
          children: [
            const SafeArea(bottom: false, child: AuthHero()),
            Expanded(child: panel),
          ],
        ),
      ),
    );
  }
}
