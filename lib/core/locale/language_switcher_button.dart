import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import 'locale_controller.dart';

/// AppBar action that lets the user manually pick pt/ja, or go back to
/// following the device's own language setting. Shared by the login
/// screen and both home screens.
/// pt/jaを手動で選択、または端末自体の言語設定に従う状態に戻せる
/// AppBarアクション。ログイン画面・両方のホーム画面で共用する。
///
/// Language names in the menu are shown in their own language (e.g.
/// "Português" / "日本語") rather than translated into the current
/// locale — this is the standard convention so a user can find their own
/// language even if the current UI is unreadable to them.
/// メニュー内の言語名は、現在の言語に翻訳せずそれぞれの言語自体で表示する
/// （例: "Português" / "日本語"）— 現在のUIが読めない状態でも自分の
/// 言語を見つけられるようにする標準的な慣習。
class LanguageSwitcherButton extends ConsumerWidget {
  const LanguageSwitcherButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(localeControllerProvider);

    return PopupMenuButton<Locale?>(
      icon: const Icon(Icons.language),
      tooltip: l10n.languageSwitcherTooltip,
      onSelected: (locale) =>
          ref.read(localeControllerProvider.notifier).setLocale(locale),
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: null,
          checked: current == null,
          child: Text(l10n.languageOptionSystem),
        ),
        const PopupMenuDivider(),
        for (final locale in supportedLocales)
          CheckedPopupMenuItem(
            value: locale,
            checked: current == locale,
            child: Text(_nativeName(locale)),
          ),
      ],
    );
  }

  String _nativeName(Locale locale) => switch (locale.languageCode) {
    'pt' => 'Português',
    'ja' => '日本語',
    _ => locale.languageCode,
  };
}
