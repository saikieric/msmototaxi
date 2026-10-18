import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/locale/language_switcher_button.dart';
import '../../flavors.dart';
import '../../l10n/generated/app_localizations.dart';

/// Sign-in screen, shared by both flavors.
/// 両flavor共通のログイン画面。
///
/// The button creates a real anonymous Supabase session tagged with the
/// app's flavor as the role ('passenger' or 'driver') — see
/// AuthRepository.signInAnonymously. Real phone-OTP sign-in (see
/// AuthRepository.signInWithPhoneOtp) is implemented but not wired up to
/// any UI yet, since Supabase's SMS provider isn't configured.
///
/// ボタンは、flavorをロール（'passenger'または'driver'）として付与した
/// 実際の匿名Supabaseセッションを作成する —
/// AuthRepository.signInAnonymously参照。実際の電話番号OTPログイン
/// （AuthRepository.signInWithPhoneOtp参照）は実装済みだが、SupabaseのSMS
/// プロバイダが未設定のためまだUIに繋がっていない。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isSigningIn = false;

  Future<void> _signIn() async {
    final flavor = AppConfig.instance.flavor;
    setState(() => _isSigningIn = true);
    try {
      await AuthRepository.instance.signInAnonymously(
        role: flavor == Flavor.driver ? 'driver' : 'passenger',
      );
      // No navigation call needed — app_router.dart's redirect re-evaluates
      // on the auth state change this triggers.
      // ナビゲーションの呼び出しは不要 — この操作が発生させる認証状態の
      // 変化を受けて、app_router.dartのredirectが再評価される。
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loginFailedMessage(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flavor = AppConfig.instance.flavor;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: const [LanguageSwitcherButton()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    flavor == Flavor.driver
                        ? Icons.two_wheeler
                        : Icons.motorcycle,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    flavor == Flavor.driver
                        ? l10n.appTitleDriver
                        : l10n.appTitlePassenger,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    flavor == Flavor.driver
                        ? l10n.loginDriverSubtitle
                        : l10n.loginPassengerSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _isSigningIn ? null : _signIn,
                    child: _isSigningIn
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.loginButton),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
