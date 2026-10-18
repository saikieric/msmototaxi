// Behavior of a passenger ride request: the inserted row, which statuses
// can be cancelled, and what the home-screen panel shows for each.
//
// 乗客の配車依頼の挙動: 挿入する行、キャンセルできるステータス、
// 各状態でホーム画面のパネルが何を出すか。

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:msmototaxi/features/passenger/home/passenger_home_screen.dart';
import 'package:msmototaxi/features/passenger/home/ride.dart';
import 'package:msmototaxi/l10n/generated/app_localizations.dart';

void main() {
  test('request row uses auth user, requested status, and lon/lat points', () {
    // Registro-ish coordinates. WKT is longitude first; swapping them would
    // land the point in the ocean.
    // Registro付近の座標。WKTは経度が先。入れ替えると海上になる。
    final row = rideRequestRow(
      passengerId: 'user-1',
      pickupLatitude: -24.495,
      pickupLongitude: -47.8433,
      dropoffLatitude: -24.5,
      dropoffLongitude: -47.85,
    );

    expect(row, {
      'passenger_id': 'user-1',
      'status': 'requested',
      'pickup_location': 'SRID=4326;POINT(-47.843300 -24.495000)',
      'dropoff_location': 'SRID=4326;POINT(-47.850000 -24.500000)',
    });
  });

  test('cancel patch marks the ride cancelled at a UTC timestamp', () {
    final at = DateTime.utc(2026, 10, 18, 12);
    expect(rideCancelPatch(cancelledAt: at), {
      'status': 'cancelled',
      'cancelled_at': '2026-10-18T12:00:00.000Z',
    });
  });

  test('only a requested ride can be cancelled', () {
    for (final status in RideStatus.values) {
      final ride = Ride(id: 'ride-1', status: status);
      expect(
        ride.canCancel,
        status == RideStatus.requested,
        reason: status.name,
      );
    }
  });

  test('active filter matches RideStatus.isActive', () {
    expect(
      RideStatus.values
          .where((status) => status.isActive)
          .map((s) => s.dbValue),
      activeRideStatusValues,
    );
  });

  test('Ride.fromRow reads id and status', () {
    final ride = Ride.fromRow({'id': 'abc', 'status': 'en_route'});
    expect(ride.id, 'abc');
    expect(ride.status, RideStatus.enRoute);
    expect(ride.isActive, isTrue);
    expect(ride.canCancel, isFalse);
  });

  test('Ride.fromRow rejects an unknown status', () {
    expect(
      () => Ride.fromRow({'id': 'abc', 'status': 'nope'}),
      throwsFormatException,
    );
  });

  testWidgets('requested ride shows its status and a cancel button', (
    tester,
  ) async {
    var cancelled = false;
    await _pumpPanel(
      tester,
      ride: const Ride(id: 'ride-1', status: RideStatus.requested),
      canRequest: false,
      onCancel: () => cancelled = true,
    );

    expect(find.text('Corrida: solicitada'), findsOneWidget);
    expect(find.text('Cancelar solicitação'), findsOneWidget);
    expect(find.text('Solicitar corrida'), findsNothing);

    await tester.tap(find.text('Cancelar solicitação'));
    await tester.pump();
    expect(cancelled, isTrue);
  });

  testWidgets('a cancelled ride shows status and can be requested again', (
    tester,
  ) async {
    var requested = false;
    await _pumpPanel(
      tester,
      ride: const Ride(id: 'ride-1', status: RideStatus.cancelled),
      canRequest: true,
      onRequest: () => requested = true,
    );

    expect(find.text('Corrida: cancelada'), findsOneWidget);
    expect(find.text('Cancelar solicitação'), findsNothing);

    await tester.tap(find.text('Solicitar corrida'));
    await tester.pump();
    expect(requested, isTrue);
  });

  testWidgets('a matched ride shows status and no cancel or new request', (
    tester,
  ) async {
    var requested = false;
    await _pumpPanel(
      tester,
      ride: const Ride(id: 'ride-1', status: RideStatus.matched),
      canRequest: false,
      onRequest: () => requested = true,
    );

    expect(find.text('Corrida: motorista encontrado'), findsOneWidget);
    expect(find.text('Cancelar solicitação'), findsNothing);

    await tester.tap(find.text('Solicitar corrida'));
    await tester.pump();
    expect(requested, isFalse);
  });

  testWidgets('before a ride, the request button waits for both points', (
    tester,
  ) async {
    var requested = false;
    await _pumpPanel(
      tester,
      ride: null,
      canRequest: false,
      onRequest: () => requested = true,
    );

    expect(find.text('Solicitar corrida'), findsOneWidget);
    expect(find.textContaining('Corrida:'), findsNothing);

    await tester.tap(find.text('Solicitar corrida'));
    await tester.pump();
    expect(requested, isFalse);
  });
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required Ride? ride,
  required bool canRequest,
  VoidCallback? onRequest,
  VoidCallback? onCancel,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('pt'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RideRequestPanel(
          ride: ride,
          canRequest: canRequest,
          isSubmitting: false,
          onRequest: onRequest ?? () {},
          onCancel: onCancel ?? () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
