import 'package:flutter/material.dart';

import '../../../core/auth/auth_repository.dart';

/// Driver home screen.
/// ドライバー用ホーム画面。
///
/// Placeholder for the online/offline toggle and incoming-ride-request UI.
/// Once Supabase exists, going online will start streaming this driver's
/// GPS position to Realtime (per slides.md "位置情報・地理検索") and
/// subscribe to incoming match offers from the matching Edge Function.
/// オンライン／オフライン切り替えと配車依頼受信UIのプレースホルダー。
/// Supabase構築後は、オンラインにするとこのドライバーのGPS位置情報を
/// Realtimeへ配信開始し（slides.md「位置情報・地理検索」参照）、
/// マッチング用Edge Functionからの依頼をsubscribeする。
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _isOnline = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MotoGo ドライバー'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () => AuthRepository.instance.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: _isOnline
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  _isOnline ? Icons.circle : Icons.circle_outlined,
                  color: _isOnline ? Colors.green : Colors.grey,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Text(
                  _isOnline ? 'オンライン（依頼を受付中）' : 'オフライン',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Switch(
                  value: _isOnline,
                  onChanged: (value) {
                    setState(() => _isOnline = value);
                    // TODO: Once Supabase is connected, start/stop
                    // streaming this driver's location to Realtime here.
                    // TODO: Supabase接続後、ここでこのドライバーの位置情報を
                    // Realtimeへ配信開始／停止する。
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.motorcycle,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isOnline ? '依頼を待っています…' : 'オンラインにすると依頼を受け取れます',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
