import 'package:flutter/material.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/supabase/supabase_config.dart';
import '../../flavors.dart';

/// Phone-OTP sign-in screen, shared by both flavors.
/// 両flavor共通の電話番号OTPログイン画面。
///
/// Two steps: enter phone number -> enter the SMS code Supabase Auth sends.
/// 2段階: 電話番号を入力 → Supabase Authが送るSMSコードを入力。
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _LoginStep { enterPhone, enterOtp }

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _LoginStep _step = _LoginStep.enterPhone;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await AuthRepository.instance.signInWithPhoneOtp(_phoneController.text);
      if (!mounted) return;
      setState(() => _step = _LoginStep.enterOtp);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'コードの送信に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await AuthRepository.instance.verifyPhoneOtp(
        phone: _phoneController.text,
        otp: _otpController.text,
      );
      // On success, the router's auth listener redirects automatically.
      // 成功時はルーターの認証リスナーが自動的にリダイレクトする。
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '認証コードが正しくありません: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flavor = AppConfig.instance.flavor;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      flavor == Flavor.driver
                          ? Icons.two_wheeler
                          : Icons.motorcycle,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppConfig.instance.appTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      flavor == Flavor.driver ? 'ドライバー用アプリ' : '乗客用アプリ',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    if (!SupabaseConfig.isConfigured) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Supabaseが未接続です。.env にプロジェクトのURLとanon keyを'
                          '設定してください（.env.example参照）。',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_step == _LoginStep.enterPhone) ..._buildPhoneStep(),
                    if (_step == _LoginStep.enterOtp) ..._buildOtpStep(),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPhoneStep() {
    return [
      TextFormField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: '電話番号',
          hintText: '+5513999999999',
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return '電話番号を入力してください';
          if (!value.trim().startsWith('+')) {
            return '国番号付き（例: +55...）で入力してください';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _isSubmitting ? null : _sendOtp,
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('認証コードを送信'),
      ),
    ];
  }

  List<Widget> _buildOtpStep() {
    return [
      TextFormField(
        controller: _otpController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'SMSで届いた認証コード',
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return 'コードを入力してください';
          return null;
        },
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _isSubmitting ? null : _verifyOtp,
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('ログイン'),
      ),
      TextButton(
        onPressed: _isSubmitting
            ? null
            : () => setState(() => _step = _LoginStep.enterPhone),
        child: const Text('電話番号を変更する'),
      ),
    ];
  }
}
