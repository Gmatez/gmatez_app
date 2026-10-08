import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/di/core_providers.dart';
import '../../domain/validators/auth_validators.dart';
import '../state/auth_notifier.dart';
import '../state/auth_state.dart';
import 'otp_screen.dart';

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
      await showPhoneOtpSheet(context);
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
    final offlineDetail = failure?.kind.name == 'offline'
        ? 'API ${ref.watch(appConfigProvider).apiBaseUrl}'
        : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        resizeToAvoidBottomInset: true,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryDim,
                AppColors.primary,
                AppColors.primarySoft,
              ],
              stops: [0.0, 0.46, 1],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: _LoginAtmospherePainter()),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return _LoginLayout(
                      viewportHeight: constraints.maxHeight,
                      illustration: const _CallingIllustration(),
                      form: _PhoneContinueForm(
                        dialCode: _dialCode,
                        phone: _phone,
                        busy: busy,
                        error: error,
                        offlineDetail: offlineDetail,
                        onDialCodeChanged: (value) {
                          setState(() => _dialCode = value);
                        },
                        onPhoneChanged: () {
                          if (_localError != null) {
                            setState(() => _localError = null);
                          }
                        },
                        onSubmit: _submit,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginLayout extends StatelessWidget {
  const _LoginLayout({
    required this.viewportHeight,
    required this.illustration,
    required this.form,
  });

  final double viewportHeight;
  final Widget illustration;
  final Widget form;

  @override
  Widget build(BuildContext context) {
    const formBlock = 148.0;
    final bottomPad = viewportHeight < 640 ? 16.0 : 24.0;
    final heroHeight = (viewportHeight - formBlock - bottomPad).clamp(
      140.0,
      viewportHeight,
    );
    final horizontal = viewportHeight < 640 ? 20.0 : 22.0;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: viewportHeight),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              height: heroHeight,
              width: double.infinity,
              child: illustration,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                8,
                horizontal,
                bottomPad,
              ),
              child: form,
            ),
          ],
        ),
      ),
    );
  }
}

class _CallingIllustration extends StatelessWidget {
  const _CallingIllustration();

  static const _asset = 'assets/brand/calling_illustration.png';

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
      child: Image(
        image: AssetImage(_asset),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      ),
    );
  }
}

class _PhoneContinueForm extends StatelessWidget {
  const _PhoneContinueForm({
    required this.dialCode,
    required this.phone,
    required this.busy,
    required this.error,
    required this.offlineDetail,
    required this.onDialCodeChanged,
    required this.onPhoneChanged,
    required this.onSubmit,
  });

  final String dialCode;
  final TextEditingController phone;
  final bool busy;
  final String? error;
  final String? offlineDetail;
  final ValueChanged<String> onDialCodeChanged;
  final VoidCallback onPhoneChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.92),
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: dialCode,
                  isDense: true,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  dropdownColor: AppColors.primaryDim,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: '+91',
                      child: Text(
                        '+91',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: '+1',
                      child: Text(
                        '+1',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: '+44',
                      child: Text(
                        '+44',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value != null) onDialCodeChanged(value);
                        },
                ),
              ),
              Container(
                width: 1,
                height: 22,
                color: Colors.white.withValues(alpha: 0.45),
              ),
              Expanded(
                child: TextField(
                  controller: phone,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  cursorColor: Colors.white,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: Colors.transparent,
                    hintText: 'Phone number',
                    hintStyle: TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                  ),
                  onChanged: (_) => onPhoneChanged(),
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.dangerSoft),
          ),
          if (offlineDetail != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                offlineDetail!,
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
            onPressed: busy ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.72),
              disabledForegroundColor: AppColors.primary,
              elevation: 0,
              shape: const StadiumBorder(),
            ),
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Row(
                    children: [
                      SizedBox(width: 28),
                      Expanded(
                        child: Text(
                          'Continue',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded),
                      SizedBox(width: 4),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _LoginAtmospherePainter extends CustomPainter {
  const _LoginAtmospherePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    canvas.drawCircle(
      Offset(width * 1.05, height * 0.94),
      width * 0.58,
      Paint()..color = const Color(0x22FFFFFF),
    );
    canvas.drawCircle(
      Offset(-width * 0.16, height * 0.8),
      width * 0.48,
      Paint()..color = const Color(0x18FFFFFF),
    );
    canvas.drawCircle(
      Offset(width * 0.96, height * 0.14),
      width * 0.26,
      Paint()..color = const Color(0x14FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
