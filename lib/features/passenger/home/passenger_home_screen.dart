import 'package:flutter/material.dart';

import '../../../core/auth/auth_repository.dart';

/// Passenger home screen.
/// 乗客用ホーム画面。
///
/// Placeholder for the map + ride-request flow described in slides.md
/// ("アプリの仕組み"): the map/route search will be Mapbox or Google Maps,
/// and matching will go through a Supabase Edge Function once the backend
/// exists. For now this just shows where that UI will live.
/// slides.md「アプリの仕組み」に記載の地図＋配車依頼フローのプレースホルダー。
/// 地図・ルート検索はMapbox（またはGoogle Maps）、マッチングはバックエンド
/// 構築後にSupabase Edge Functionを経由する予定。現時点ではUIの配置場所のみ示す。
class PassengerHomeScreen extends StatelessWidget {
  const PassengerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MotoGo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () => AuthRepository.instance.signOut(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // TODO: Replace with a real map view (Mapbox/Google Maps) once
          // the map SDK and API keys are wired up.
          // TODO: 地図SDKとAPIキーを設定したら、実際の地図表示
          // （Mapbox/Google Maps）に置き換える。
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '地図はここに表示されます\n（Mapbox / Google Maps 予定）',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'どこに行きますか？',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '配車依頼機能は準備中です（Supabase接続後に実装）',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.motorcycle),
                      label: const Text('配車を依頼する'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
