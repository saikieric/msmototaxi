/// MotoGo's visual identity: light/dark [ThemeData] built around two colors
/// specific to Registro itself, rather than a generic ride-hailing palette.
/// See the "MotoGo Visual Identity" design artifact for the full rationale
/// — in short:
/// - **Torii** (vermillion): Registro's Torii gate, built 1993 to mark the
///   arrival of the first Japanese immigrants to São Paulo state. Used for
///   primary actions and the dropoff marker.
/// - **Tea** (muted green): Registro has been the official "State Capital
///   of Tea" (Lei 4.067/84) since 1984, from its tea plantations. Used for
///   secondary/status accents (driver online, pickup marker).
///
/// This deliberately replaces the placeholder lavender seed color
/// (`0xFF9C8DB6`) the Flutter starter template shipped with.
///
/// MotoGoのビジュアルアイデンティティ: 一般的な配車アプリの配色ではなく、
/// Registro市自体に固有の2色を軸にした、ライト/ダーク両対応の
/// [ThemeData]。詳しい経緯は「MotoGo Visual Identity」デザインArtifact
/// 参照 — 要約すると:
/// - **Torii（鳥居・朱色）**: 1993年、サンパウロ州への日系移民第一陣の
///   到着を記念して建てられたRegistroの鳥居。主要なアクション、
///   降車地点マーカーに使用。
/// - **Tea（茶・落ち着いた緑）**: Registroは1984年の州法（4.067/84号）
///   により正式に「茶の州都」を名乗る、茶畑の町。副次的なアクセント
///   （ドライバーのオンライン状態、乗車地点マーカー）に使用。
///
/// これは、Flutterの初期テンプレートが持っていた仮のラベンダー色の
/// seedColor（`0xFF9C8DB6`）を意図的に置き換えるもの。
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Raw brand colors, exposed directly for call sites that need a [Color]
/// without a [BuildContext] to hand (e.g. the marker bitmaps drawn in
/// `passenger_home_screen.dart`'s `initState`). Everywhere else, prefer
/// reading `Theme.of(context).colorScheme` so light/dark mode is handled
/// automatically.
/// [BuildContext]を渡せない呼び出し元（例:
/// `passenger_home_screen.dart`の`initState`内で描画するマーカー画像）の
/// ために、生の色を直接公開している。それ以外の場所では、ライト/ダーク
/// モードが自動で切り替わるよう`Theme.of(context).colorScheme`を
/// 参照すること。
const toriiAccent = Color(0xFFC1442B);
const teaAccent = Color(0xFF55704C);

const _toriiOnAccent = Color(0xFFFBF3EE);
const _teaOnAccent = Color(0xFFF2F6EE);

const _paperLight = Color(0xFFEEF0E7);
const _surfaceLight = Color(0xFFFBFAF4);
const _surfaceHighLight = Color(0xFFE4E7DB);
const _fgLight = Color(0xFF232A1F);
const _outlineLight = Color(0xFF656F5A);
const _borderLight = Color(0xFFD9DCC9);

const _bgDark = Color(0xFF14180F);
const _surfaceDark = Color(0xFF1B2015);
const _surfaceHighDark = Color(0xFF262C1D);
const _fgDark = Color(0xFFECEEE2);
const _outlineDark = Color(0xFF9CA48D);
const _borderDark = Color(0xFF333A26);
const _toriiAccentDark = Color(0xFFE2724F);
const _toriiOnAccentDark = Color(0xFF2B1108);
const _teaAccentDark = Color(0xFF8FAE81);
const _teaOnAccentDark = Color(0xFF101B0C);

final ColorScheme motogoLightColorScheme = ColorScheme.light(
  primary: toriiAccent,
  onPrimary: _toriiOnAccent,
  primaryContainer: _surfaceHighLight,
  onPrimaryContainer: _fgLight,
  secondary: teaAccent,
  onSecondary: _teaOnAccent,
  secondaryContainer: _surfaceHighLight,
  onSecondaryContainer: _fgLight,
  surface: _paperLight,
  onSurface: _fgLight,
  surfaceContainer: _surfaceLight,
  surfaceContainerHighest: _surfaceHighLight,
  outline: _outlineLight,
  outlineVariant: _borderLight,
);

final ColorScheme motogoDarkColorScheme = ColorScheme.dark(
  primary: _toriiAccentDark,
  onPrimary: _toriiOnAccentDark,
  primaryContainer: _surfaceHighDark,
  onPrimaryContainer: _fgDark,
  secondary: _teaAccentDark,
  onSecondary: _teaOnAccentDark,
  secondaryContainer: _surfaceHighDark,
  onSecondaryContainer: _fgDark,
  surface: _bgDark,
  onSurface: _fgDark,
  surfaceContainer: _surfaceDark,
  surfaceContainerHighest: _surfaceHighDark,
  outline: _outlineDark,
  outlineVariant: _borderDark,
);

/// Unbounded for display-scale text (the wordmark, screen headlines) paired
/// with Noto Sans JP for everything else, since body text has to render
/// both Portuguese and Japanese equally well.
/// 見出し・ワードマーク用にUnbounded、それ以外はNoto Sans JPを使う —
/// 本文はポルトガル語・日本語のどちらも同じ品質で表示する必要があるため。
TextTheme _motogoTextTheme(ColorScheme scheme) {
  final base = GoogleFonts.notoSansJpTextTheme().apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  return base.copyWith(
    headlineMedium: GoogleFonts.unbounded(
      textStyle: base.headlineMedium,
      fontWeight: FontWeight.w700,
    ),
    headlineSmall: GoogleFonts.unbounded(
      textStyle: base.headlineSmall,
      fontWeight: FontWeight.w600,
    ),
  );
}

ThemeData _motogoTheme(ColorScheme scheme) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: _motogoTextTheme(scheme),
  );
}

final ThemeData motogoLightTheme = _motogoTheme(motogoLightColorScheme);
final ThemeData motogoDarkTheme = _motogoTheme(motogoDarkColorScheme);
