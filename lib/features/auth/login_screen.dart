import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/locale/language_switcher_button.dart';
import '../../core/supabase/supabase_config.dart';
import '../../flavors.dart';
import '../../l10n/generated/app_localizations.dart';

/// Sign-in screen, shared by both flavors.
/// 両flavor共通のログイン画面。
///
/// The button calls [AuthRepository.signInAnonymously] so the session —
/// and therefore `auth.uid()` — is real. Phone OTP stays on
/// [AuthRepository] for when the SMS provider is configured; this screen
/// does not collect a phone number yet.
/// ボタンは [AuthRepository.signInAnonymously] を呼び、セッション
/// （したがって `auth.uid()`）が本物になる。電話番号OTPは SMS プロバイダ
/// 設定後のために [AuthRepository] に残してある。この画面はまだ電話番号を
/// 入力させない。
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _submitting = false;
  String? _error;

  Future<void> _signIn() async {
    if (!SupabaseConfig.isConfigured || _submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AuthRepository.instance.signInAnonymously(
        role: AppConfig.instance.flavor.name,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flavor = AppConfig.instance.flavor;
    final l10n = AppLocalizations.of(context)!;
    final configured = SupabaseConfig.isConfigured;
    final scheme = Theme.of(context).colorScheme;
    final bannerColor = configured
        ? scheme.secondaryContainer
        : scheme.errorContainer;
    final bannerOnColor = configured
        ? scheme.onSecondaryContainer
        : scheme.onErrorContainer;

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
                    color: scheme.primary,
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bannerColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      configured
                          ? l10n.loginAnonymousBanner
                          : l10n.loginNotConfigured,
                      style: TextStyle(color: bannerOnColor),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.loginError(_error!),
                      style: TextStyle(color: scheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: configured && !_submitting ? _signIn : null,
                    child: _submitting
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
