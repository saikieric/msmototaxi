import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/locale/locale_controller.dart';
import 'core/router/app_router.dart';
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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9C8DB6),
        ),
      ),
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
