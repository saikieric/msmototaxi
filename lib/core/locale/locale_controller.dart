import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Locales this app ships translations for. First entry is the default/
/// fallback used when the device's language isn't in this list.
/// このアプリが翻訳を持つ言語一覧。先頭がデフォルト/フォールバック
/// （端末の言語がこの一覧に無い場合に使われる）。
///
/// pt (Brazilian Portuguese) is the default — most end users in Registro,
/// SP are Brazilian; ja is for the dev team / eventual Japanese users. See
/// slides.md for the target market.
/// ptを（ブラジルポルトガル語）デフォルトにしている — Registro市の
/// エンドユーザーの大半はブラジル人で、jaは開発チーム/将来的な日本人
/// ユーザー向け。対象市場はslides.md参照。
const supportedLocales = [Locale('pt'), Locale('ja')];

const _prefsKey = 'locale_override';

/// The user's manually-picked locale, or null to follow the device's own
/// language setting (resolved against [supportedLocales] elsewhere — see
/// `app.dart`'s `localeResolutionCallback`).
/// ユーザーが手動で選んだ言語。nullなら端末自体の言語設定に従う
/// （[supportedLocales] との突き合わせは他の場所 — `app.dart` の
/// `localeResolutionCallback` — で行う）。
///
/// Persisted via SharedPreferences so the choice survives app restarts.
/// The initial value is loaded synchronously at startup (see
/// `bootstrap.dart`) and passed in as this notifier's starting state,
/// since SharedPreferences itself is only accessible asynchronously.
/// SharedPreferences経由で永続化し、アプリ再起動後も選択が保持される。
/// SharedPreferences自体は非同期でしかアクセスできないため、初期値は
/// 起動時（`bootstrap.dart`参照）に読み込んでおき、このnotifierの
/// 初期stateとして渡す。
class LocaleController extends Notifier<Locale?> {
  LocaleController(this._prefs, this._initial);

  final SharedPreferences _prefs;
  final Locale? _initial;

  @override
  Locale? build() => _initial;

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    if (locale == null) {
      await _prefs.remove(_prefsKey);
    } else {
      await _prefs.setString(_prefsKey, locale.languageCode);
    }
  }
}

/// Reads the persisted locale override, if any, without needing the full
/// provider graph — call this once at startup (see `bootstrap.dart`)
/// before the [localeControllerProvider] override is built.
/// 永続化された言語選択を、provider全体を構築せずに読む —
/// 起動時（`bootstrap.dart`参照）、[localeControllerProvider] の
/// overrideを組み立てる前に一度だけ呼ぶ。
Locale? readPersistedLocale(SharedPreferences prefs) {
  final code = prefs.getString(_prefsKey);
  if (code == null) return null;
  return supportedLocales.firstWhere(
    (l) => l.languageCode == code,
    orElse: () => supportedLocales.first,
  );
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale?>(
  () => throw UnimplementedError(
    'localeControllerProvider must be overridden in bootstrap.dart with a '
    'real SharedPreferences instance and the persisted initial locale.',
  ),
);
