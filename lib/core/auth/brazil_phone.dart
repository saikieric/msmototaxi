/// Brazilian mobile numbers as E.164 for Supabase phone OTP.
/// Supabaseの電話番号OTP向けに、ブラジルの携帯番号をE.164にする。
///
/// Registro riders and drivers enter a national number (DDD + 9 digits).
/// A leading `+55` or `55` is accepted too. Landlines and unknown DDDs
/// are rejected — SMS OTP needs a mobile.
/// Registroの乗客・ドライバーは国内番号（市外局番 + 9桁）を入力する。
/// 先頭の `+55` や `55` も受け付ける。固定電話と未知の市外局番は
/// 拒否する — SMSのOTPには携帯が必要。
library;

const _brazilianDdds = {
  '11', '12', '13', '14', '15', '16', '17', '18', '19',
  '21', '22', '24', '27', '28',
  '31', '32', '33', '34', '35', '37', '38',
  '41', '42', '43', '44', '45', '46', '47', '48', '49',
  '51', '53', '54', '55',
  '61', '62', '63', '64', '65', '66', '67', '68', '69',
  '71', '73', '74', '75', '77', '79',
  '81', '82', '83', '84', '85', '86', '87', '88', '89',
  '91', '92', '93', '94', '95', '96', '97', '98', '99',
};

/// Returns `+55` plus 11 national digits, or null when [raw] is not a
/// Brazilian mobile number.
/// ブラジルの携帯番号なら `+55` と国内11桁を返す。[raw] がそれで
/// なければ null。
String? brazilMobileE164(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final hadPlus = trimmed.startsWith('+');
  var digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;

  // `00` is the international prefix some people type instead of `+`.
  // `+` の代わりに打つ国際プレフィックス `00`。
  if (digits.startsWith('00')) {
    return _fromCountryDigits(digits.substring(2));
  }
  if (hadPlus) return _fromCountryDigits(digits);

  if (digits.startsWith('0')) {
    digits = digits.replaceFirst(RegExp(r'^0+'), '');
  }

  if (digits.length == 11) return _nationalToE164(digits);
  // 13 digits starting with 55 is country code + national mobile.
  // DDD 55 (Rio Grande do Sul) is only 11 digits without the country code,
  // so it does not take this branch.
  // 55で始まる13桁は国番号 + 国内携帯。市外局番55（リオグランデ・ド・スル）は
  // 国番号なしだと11桁なので、この分岐には入らない。
  if (digits.length == 13 && digits.startsWith('55')) {
    return _nationalToE164(digits.substring(2));
  }
  return null;
}

String? _fromCountryDigits(String digits) {
  if (!digits.startsWith('55') || digits.length != 13) return null;
  return _nationalToE164(digits.substring(2));
}

String? _nationalToE164(String national) {
  if (national.length != 11) return null;
  if (!_brazilianDdds.contains(national.substring(0, 2))) return null;
  // Brazilian mobiles are DDD + 9 + 8 digits.
  // ブラジルの携帯は市外局番 + 9 + 8桁。
  if (national[2] != '9') return null;
  return '+55$national';
}
