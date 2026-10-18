import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_mode.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/brazil_phone.dart';
import '../../core/auth/otp_failure.dart';
import '../../core/locale/language_switcher_button.dart';
import '../../core/supabase/supabase_config.dart';
import '../../flavors.dart';
import '../../l10n/generated/app_localizations.dart';

/// Sign-in screen, shared by both flavors.
/// 両flavor共通のログイン画面。
///
/// Default path: a Brazilian mobile number, then the SMS code from
/// Supabase phone auth (Twilio Verify). [kAnonymousAuthFallback] adds an
/// anonymous button for dev/test builds. While `.env` is still the
/// placeholder, every submit stays disabled and a not-connected snackbar
/// is shown if a submit still runs.
/// 既定の経路: ブラジルの携帯番号、続けてSupabase電話認証（Twilio Verify）の
/// SMSコード。[kAnonymousAuthFallback] が有効な開発/テストビルドでは
/// 匿名ボタンも出す。`.env` がプレースホルダーの間は送信をすべて無効にし、
/// それでも送信が走った場合は未接続のスナックバーを出す。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _LoginStep { phone, code }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  _LoginStep _step = _LoginStep.phone;
  bool _submitting = false;
  String? _error;
  String? _e164;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// `.env` unconfigured — don't call Supabase. The banner already says
  /// so; this snackbar covers a submit that still fires.
  /// `.env` が未設定のときは Supabase を呼ばない。バナーでも伝えており、
  /// このスナックバーは送信が走ってしまった場合のガード。
  bool _ensureConfigured() {
    if (SupabaseConfig.isConfigured) return true;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.loginNotConnectedMessage)));
    return false;
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    _cooldownSeconds = seconds;
    if (seconds <= 0) return;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds -= 1;
        if (_cooldownSeconds <= 0) {
          _cooldownSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendCode() async {
    if (!_ensureConfigured() || _submitting || _cooldownSeconds > 0) return;
    final l10n = AppLocalizations.of(context)!;
    final e164 = brazilMobileE164(_phoneController.text);
    if (e164 == null) {
      setState(() => _error = l10n.loginErrorInvalidPhone);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithPhoneOtp(
            phone: e164,
            role: AppConfig.instance.flavor.name,
          );
      if (!mounted) return;
      setState(() {
        _e164 = e164;
        _step = _LoginStep.code;
        _codeController.clear();
      });
      _startCooldown(kSmsResendCooldownSeconds);
    } on AuthException catch (e) {
      if (!mounted) return;
      _applyAuthError(e, OtpAttempt.send);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = l10n.loginError(e.toString()));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _verifyCode() async {
    final e164 = _e164;
    if (!_ensureConfigured() || _submitting || e164 == null) return;
    final l10n = AppLocalizations.of(context)!;
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = l10n.loginErrorWrongCode);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyPhoneOtp(phone: e164, otp: code);
    } on AuthException catch (e) {
      if (!mounted) return;
      _applyAuthError(e, OtpAttempt.verify);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = l10n.loginError(e.toString()));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _signInAnonymously() async {
    if (!_ensureConfigured() || _submitting) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signInAnonymously(role: AppConfig.instance.flavor.name);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = l10n.loginError(e.message));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = l10n.loginError(e.toString()));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _applyAuthError(AuthException error, OtpAttempt attempt) {
    final l10n = AppLocalizations.of(context)!;
    final failure = classifyOtpFailure(error, attempt: attempt);
    if (failure == OtpFailure.resendCooldown) {
      _startCooldown(
        cooldownSecondsFromMessage(error.message) ?? kSmsResendCooldownSeconds,
      );
    }
    setState(() => _error = _messageFor(l10n, failure, error));
  }

  String _messageFor(
    AppLocalizations l10n,
    OtpFailure failure,
    AuthException error,
  ) {
    return switch (failure) {
      OtpFailure.invalidPhone => l10n.loginErrorInvalidPhone,
      OtpFailure.wrongCode => l10n.loginErrorWrongCode,
      OtpFailure.resendCooldown => l10n.loginErrorResendCooldown,
      OtpFailure.other => l10n.loginError(error.message),
    };
  }

  void _changeNumber() {
    _cooldownTimer?.cancel();
    setState(() {
      _step = _LoginStep.phone;
      _e164 = null;
      _error = null;
      _cooldownSeconds = 0;
      _codeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final flavor = AppConfig.instance.flavor;
    final l10n = AppLocalizations.of(context)!;
    final configured = SupabaseConfig.isConfigured;
    final scheme = Theme.of(context).colorScheme;
    final bannerColor = configured
        ? scheme.secondaryContainer
        : scheme.errorContainer;
    final bannerOnColor = configured
        ? scheme.onSecondaryContainer
        : scheme.onErrorContainer;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: const [LanguageSwitcherButton()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    flavor == Flavor.driver
                        ? Icons.two_wheeler
                        : Icons.motorcycle,
                    size: 64,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    flavor == Flavor.driver
                        ? l10n.appTitleDriver
                        : l10n.appTitlePassenger,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    flavor == Flavor.driver
                        ? l10n.loginDriverSubtitle
                        : l10n.loginPassengerSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bannerColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      configured
                          ? l10n.loginPhoneBanner
                          : l10n.loginNotConfigured,
                      style: TextStyle(color: bannerOnColor),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: scheme.error)),
                  ],
                  const SizedBox(height: 16),
                  if (_step == _LoginStep.phone)
                    ..._phoneFields(l10n, configured)
                  else
                    ..._codeFields(l10n, configured),
                  if (kAnonymousAuthFallback) ...[
                    const SizedBox(height: 24),
                    Text(
                      l10n.loginAnonymousBanner,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: configured && !_submitting
                          ? _signInAnonymously
                          : null,
                      child: Text(l10n.loginAnonymousButton),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneFields(AppLocalizations l10n, bool configured) {
    return [
      TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        autofocus: true,
        autofillHints: const [AutofillHints.telephoneNumber],
        enabled: configured && !_submitting,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
        ],
        decoration: InputDecoration(
          labelText: l10n.loginPhoneLabel,
          hintText: l10n.loginPhoneHint,
          prefixText: '+55 ',
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: configured && !_submitting && _cooldownSeconds == 0
            ? _sendCode
            : null,
        child: _submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                _cooldownSeconds > 0
                    ? l10n.loginResendCooldown(_cooldownSeconds)
                    : l10n.loginSendCodeButton,
              ),
      ),
    ];
  }

  List<Widget> _codeFields(AppLocalizations l10n, bool configured) {
    final phone = _e164 ?? '';
    return [
      Text(l10n.loginCodeSentTo(phone), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        autofocus: true,
        autofillHints: const [AutofillHints.oneTimeCode],
        enabled: configured && !_submitting,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: l10n.loginCodeLabel,
          hintText: l10n.loginCodeHint,
          counterText: '',
        ),
        onChanged: (_) => setState(() => _error = null),
        onSubmitted: (_) => _verifyCode(),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed:
            configured &&
                !_submitting &&
                RegExp(r'^\d{6}$').hasMatch(_codeController.text.trim())
            ? _verifyCode
            : null,
        child: _submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(l10n.loginVerifyButton),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: configured && !_submitting && _cooldownSeconds == 0
            ? _sendCode
            : null,
        child: Text(
          _cooldownSeconds > 0
              ? l10n.loginResendCooldown(_cooldownSeconds)
              : l10n.loginResendCode,
        ),
      ),
      TextButton(
        onPressed: _submitting ? null : _changeNumber,
        child: Text(l10n.loginChangeNumber),
      ),
    ];
  }
}
