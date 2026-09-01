// Default entrypoint — defaults to the passenger flavor so plain
// `flutter run` works without extra flags during early development.
// For flavor-specific builds use main_passenger.dart / main_driver.dart
// (see README.md).
//
// デフォルトのエントリポイント。開発初期に素の `flutter run` でも動くよう
// 乗客用flavorをデフォルトにしている。flavor別ビルドは
// main_passenger.dart / main_driver.dart を使う（README.md参照）。
import 'bootstrap.dart';
import 'flavors.dart';

void main() => bootstrap(Flavor.passenger);
