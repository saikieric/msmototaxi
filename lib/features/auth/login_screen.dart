import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/dev_auth_bypass.dart';
import '../../core/locale/language_switcher_button.dart';
import '../../flavors.dart';
import '../../l10n/generated/app_localizations.dart';

/// Sign-in screen, shared by both flavors.
/// 両flavor共通のログイン画面。
///
/// Real phone-OTP sign-in (see AuthRepository) is deferred for now — the
/// button below just flips the dev-auth-bypass flag so the map/ride-request
/// screens can be built and tested first. Swap this back to the real
/// phone/OTP flow once SMS auth is configured in the Supabase Dashboard.
///
/// 実際の電話番号OTPログイン（AuthRepository参照）は後回し。下のボタンは
/// 開発用バイパスフラグを立てるだけで、先に地図・配車依頼画面を作成・確認
/// できるようにしている。Supabase DashboardでSMS認証を設定したら、
/// 実際の電話番号/OTPフローに戻すこと。
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.loginDevBypassBanner,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        ref.read(devAuthBypassProvider.notifier).state = true,
                    child: Text(l10n.loginButton),
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
