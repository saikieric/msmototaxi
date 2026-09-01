import 'bootstrap.dart';
import 'flavors.dart';

/// Entrypoint for the driver flavor:
/// `flutter run --flavor driver -t lib/main_driver.dart`
/// ドライバー用flavorのエントリポイント。
void main() => bootstrap(Flavor.driver);
