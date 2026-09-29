import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_layout.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/motion/app_motion.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/validators/auth_validators.dart';
import '../state/auth_notifier.dart';
import '../state/auth_state.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error =
        DisplayNameValidator.validate(_name.text) ??
        EmailValidator.validate(_email.text) ??
        PasswordValidator.validate(_password.text);
    setState(() => _localError = error);
    if (error != null) {
      return;
    }
    await ref
        .read(authNotifierProvider.notifier)
        .register(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final busy = auth.status == AuthStatus.authenticating;
    final error = _localError ?? auth.failure?.userMessage;

    return MistScaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: AppLayout.constrain(
          context,
          child: ListView(
            padding: AppLayout.pagePadding(context).copyWith(
              top: AppSpacing.sm,
              bottom: AppSpacing.xl,
            ),
            children: [
              const ScreenHeader(
                title: 'Create account',
                subtitle:
                    'Backend OTP login works only for existing users. Register first, then you can sign in with email/password or OTP.',
              ),
              FadeInUp(
                child: StaggeredList(
                  children: [
                    AppTextField(
                      controller: _name,
                      label: 'Display name',
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      enabled: !busy,
                    ),
                    AppTextField(
                      controller: _email,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      enabled: !busy,
                    ),
                    AppTextField(
                      controller: _password,
                      label: 'Password (min 10 characters)',
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      enabled: !busy,
                      onSubmitted: (_) => _submit(),
                    ),
                    if (error != null)
                      Text(
                        error,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    AppButton(
                      label: 'Create account',
                      loading: busy,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
