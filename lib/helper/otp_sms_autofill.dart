import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:otp_autofill/otp_autofill.dart';
import 'package:project_c/helper/app_log.dart';

/// Outcome of one Android SMS User Consent listen attempt.
enum OtpSmsListenStatus { code, canceled, failed, unsupported }

class OtpSmsListenResult {
  const OtpSmsListenResult._(this.status, [this.code]);

  const OtpSmsListenResult.code(String code)
    : this._(OtpSmsListenStatus.code, code);

  const OtpSmsListenResult.canceled() : this._(OtpSmsListenStatus.canceled);

  const OtpSmsListenResult.failed() : this._(OtpSmsListenStatus.failed);

  const OtpSmsListenResult.unsupported()
    : this._(OtpSmsListenStatus.unsupported);

  final OtpSmsListenStatus status;
  final String? code;
}

/// Android SMS User Consent auto-read for the 6-digit catalog OTP.
///
/// Uses [otp_autofill] (MethodChannel + Play Services User Consent).
/// No `READ_SMS` permission. On SMS arrival the system shows a one-tap
/// consent dialog; after Allow we parse the 6-digit code.
///
/// iOS is a no-op here — use [AutofillHints.oneTimeCode] on a TextField.
class OtpSmsAutofill {
  OtpSmsAutofill._();

  static const _tag = 'OtpSmsAutofill';
  static const int codeLength = 6;

  /// Play Services User Consent listens for ~5 minutes.
  static const Duration _listenTimeout = Duration(minutes: 5, seconds: 15);

  static OTPInteractor? _interactor;

  static OTPInteractor get _otp {
    return _interactor ??= OTPInteractor();
  }

  /// Starts listening (Android only).
  static Future<OtpSmsListenResult> listenForCode() async {
    if (!Platform.isAndroid) {
      return const OtpSmsListenResult.unsupported();
    }

    try {
      AppLog.d(_tag, 'Starting SMS User Consent listener');
      final sms = await _otp
          .startListenUserConsent()
          .timeout(_listenTimeout);

      if (sms == null || sms.trim().isEmpty) {
        AppLog.d(_tag, 'User Consent returned empty SMS');
        return const OtpSmsListenResult.canceled();
      }

      final code = extractFromSms(sms) ?? normalizeCode(sms);
      AppLog.d(_tag, 'SMS received code=${code != null ? '******' : 'null'}');
      if (code == null) return const OtpSmsListenResult.failed();
      return OtpSmsListenResult.code(code);
    } on TimeoutException {
      AppLog.d(_tag, 'User Consent timed out');
      await stopListening();
      return const OtpSmsListenResult.failed();
    } on PlatformException catch (e) {
      // Plugin timeout (408) or missing native channel after hot-restart.
      AppLog.e(_tag, 'listenForCode PlatformException code=${e.code}', e);
      if (e.code == '408') return const OtpSmsListenResult.failed();
      if (e.code == 'channel-error' ||
          e.message?.contains('channel') == true ||
          e.message?.contains('MissingPlugin') == true) {
        return const OtpSmsListenResult.failed();
      }
      return const OtpSmsListenResult.failed();
    } on MissingPluginException catch (e) {
      AppLog.e(
        _tag,
        'Native plugin not linked — full rebuild required (not hot restart)',
        e,
      );
      return const OtpSmsListenResult.failed();
    } catch (e) {
      AppLog.e(_tag, 'listenForCode failed', e);
      return const OtpSmsListenResult.failed();
    }
  }

  static Future<void> stopListening() async {
    if (!Platform.isAndroid) return;
    try {
      await _otp.stopListenForCode();
    } catch (e) {
      AppLog.e(_tag, 'stopListening failed', e);
    }
  }

  /// Returns a clean 6-digit string, or null.
  static String? normalizeCode(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < codeLength) return null;
    return digits.substring(0, codeLength);
  }

  /// Pulls the first standalone 6-digit sequence from an SMS body.
  static String? extractFromSms(String sms) {
    final match = RegExp(r'\b\d{6}\b').firstMatch(sms);
    if (match != null) return match.group(0);
    final fallback = RegExp(r'\d{6}').firstMatch(sms);
    return fallback?.group(0);
  }
}
