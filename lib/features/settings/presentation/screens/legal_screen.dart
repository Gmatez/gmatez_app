import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_layout.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/motion/app_motion.dart';
import '../../../../core/widgets/app_widgets.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return MistScaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: AppLayout.constrain(
          context,
          child: FadeInUp(
            child: ListView(
              padding: AppLayout.pagePadding(context).copyWith(
                top: AppSpacing.sm,
                bottom: AppSpacing.xl,
              ),
              children: [
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.syne(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.55,
                    fontSize: 15,
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

abstract final class LegalCopy {
  static const community = '''
Gmatez is a live conversation product. Treat every caller and listener with respect.

Do not harass, impersonate, or solicit illegal activity. Sexual content involving minors is never allowed. Repeat reports can lead to suspension.

Host availability and paid calls are controlled by the backend. Circumventing billing is a violation of these guidelines.
''';

  static const terms = '''
By using Gmatez you agree that call charges, listener earnings, and payouts are calculated and settled by the backend.

Wallet credits appear only after a verified payment. Flutter never adds money locally. You are responsible for lawful use of voice and video calls.
''';

  static const privacy = '''
We store the profile, call, chat, and ledger records required to operate the product. Deleted accounts are anonymized. Financial ledgers are retained for audit.

Identity documents are not stored in this app unless a KYC provider is configured on the server.
''';

  static const contact =
      'For account, billing, or safety issues, email support through the in-app report flow or your Gmatez operator.';
}
