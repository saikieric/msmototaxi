import 'bootstrap.dart';
import 'flavors.dart';

/// Entrypoint for the passenger flavor:
/// `flutter run --flavor passenger -t lib/main_passenger.dart`
/// 乗客用flavorのエントリポイント。
void main() => bootstrap(Flavor.passenger);
