/// Which build of the app is running.
/// どのビルド（アプリ）が実行されているかを表す。
///
/// Per slides.md: passenger app and driver app share one Flutter codebase,
/// separated by build flavor (`--flavor passenger` / `--flavor driver`).
/// slides.md の通り、乗客用・ドライバー用アプリは1つのFlutterコードベースを共有し、
/// ビルドflavor（`--flavor passenger` / `--flavor driver`）で分離する。
enum Flavor { passenger, driver }

/// Global, flavor-aware app configuration.
/// flavorに応じたグローバル設定。
///
/// Set once at startup by each flavor's `main_*.dart` entrypoint, then read
/// anywhere via [AppConfig.instance].
/// 各flavorの `main_*.dart` エントリポイントで起動時に一度だけ設定し、
/// それ以降はどこからでも [AppConfig.instance] で参照する。
class AppConfig {
  AppConfig._({required this.flavor});

  static AppConfig? _instance;

  static AppConfig get instance {
    final config = _instance;
    if (config == null) {
      throw StateError(
        'AppConfig.instance accessed before AppConfig.initialize() was called.',
      );
    }
    return config;
  }

  static void initialize({required Flavor flavor}) {
    _instance = AppConfig._(flavor: flavor);
  }

  final Flavor flavor;

  bool get isPassenger => flavor == Flavor.passenger;
  bool get isDriver => flavor == Flavor.driver;

  String get appTitle => switch (flavor) {
    Flavor.passenger => 'MotoGo',
    Flavor.driver => 'MotoGo ドライバー',
  };
}
