import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/locale/locale_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/motogo_theme.dart';
import 'flavors.dart';
import 'l10n/generated/app_localizations.dart';

class MotoGoApp extends ConsumerWidget {
  const MotoGoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final localeOverride = ref.watch(localeControllerProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) {
        final l10n = AppLocalizations.of(context);
        // onGenerateTitle can theoretically run before delegates finish
        // loading, so fall back to the flavor's brand name rather than
        // crashing on a null l10n.
        // onGenerateTitleはdelegateの読み込み完了前に呼ばれる可能性が
        // 理論上あるため、l10nがnullでクラッシュせずflavorのブランド名に
        // フォールバックする。
        if (l10n == null) return AppConfig.instance.appTitle;
        return switch (AppConfig.instance.flavor) {
          Flavor.passenger => l10n.appTitlePassenger,
          Flavor.driver => l10n.appTitleDriver,
        };
      },
      debugShowCheckedModeBanner: false,
      // See core/theme/motogo_theme.dart for the palette rationale (torii
      // vermillion + tea green, both specific to Registro itself) — this
      // replaces the Flutter starter template's placeholder lavender
      // seedColor. themeMode defaults to ThemeMode.system, so the app
      // simply follows the device's own light/dark setting rather than
      // reimplementing that switch itself.
      // パレットの根拠は core/theme/motogo_theme.dart 参照
      // （鳥居の朱色＋茶畑の緑、どちらもRegistro固有）— Flutter初期
      // テンプレートの仮のラベンダー色seedColorを置き換える。themeMode は
      // デフォルトの ThemeMode.system のままにしているため、明暗切り替え
      // 自体を自前で作らず、端末側のライト/ダーク設定にそのまま従う。
      theme: motogoLightTheme,
      darkTheme: motogoDarkTheme,
      // null means "follow the device's language" — resolved against
      // supportedLocales by localeResolutionCallback below, falling back
      // to pt (see core/locale/locale_controller.dart for why pt is the
      // default). A non-null value means the user manually picked a
      // language via the language-switcher button.
      // nullは「端末の言語に従う」を意味し、下のlocaleResolutionCallbackで
      // supportedLocalesと突き合わせ、ptにフォールバックする（ptが
      // デフォルトである理由は core/locale/locale_controller.dart 参照）。
      // null以外の値は、言語切り替えボタンでユーザーが手動選択したことを
      // 意味する。
      locale: localeOverride,
      supportedLocales: supportedLocales,
      localeResolutionCallback: (deviceLocale, supported) {
        if (deviceLocale == null) return supported.first;
        // Match by language code only (e.g. a device reporting pt_BR
        // should still resolve to our pt translation) rather than
        // requiring an exact Locale match.
        // languageCodeのみで照合する（例: 端末がpt_BRを報告していても
        // ptの翻訳に解決されるべき）。厳密なLocale一致は要求しない。
        for (final locale in supported) {
          if (locale.languageCode == deviceLocale.languageCode) {
            return locale;
          }
        }
        return supported.first;
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
