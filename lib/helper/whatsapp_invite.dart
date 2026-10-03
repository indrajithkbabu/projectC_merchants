import 'dart:io';

import 'package:project_c/helper/app_log.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a WhatsApp chat with a prefilled invite message.
///
/// Tries several schemes, then falls back to the system share sheet so an
/// invite still works when the url_launcher channel is unavailable (e.g. after
/// adding the plugin without a full app restart).
abstract final class WhatsAppInvite {
  static const _tag = 'WhatsAppInvite';

  /// Default download / join link when the viewer has no store slug yet.
  static const defaultAppUrl = 'https://jewelflow.app';

  /// Telegram-style invite copy for WhatsApp / share sheet.
  ///
  /// Example:
  /// `Hey, I'm using JewelFlow to chat. Join me! Download it here: https://ikb.jewelflow.app`
  static String appInviteMessage({String? storeLink}) {
    final raw = (storeLink ?? '').trim();
    final url =
        raw.isEmpty
            ? defaultAppUrl
            : (raw.startsWith('http://') || raw.startsWith('https://')
                ? raw
                : 'https://$raw');
    return "Hey, I'm using JewelFlow to chat. Join me! Download it here: $url";
  }

  /// [phoneE164] like `+9198…`. Digits-only form is used for WhatsApp URIs.
  static Future<bool> open({
    required String phoneE164,
    required String message,
  }) async {
    final digits = phoneE164.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      AppLog.d(_tag, 'Empty phone — cannot open WhatsApp');
      return false;
    }
    final encoded = Uri.encodeComponent(message);
    final candidates = <Uri>[
      Uri.parse('whatsapp://send?phone=$digits&text=$encoded'),
      Uri.parse('https://wa.me/$digits?text=$encoded'),
      Uri.parse('https://api.whatsapp.com/send?phone=$digits&text=$encoded'),
    ];
    return _launchCandidates(candidates, fallbackMessage: message);
  }

  /// Opens WhatsApp with [message] prefilled (contact picker), then share sheet.
  static Future<bool> shareText(String message) async {
    final text = message.trim();
    if (text.isEmpty) return false;
    final encoded = Uri.encodeComponent(text);
    final candidates = <Uri>[
      Uri.parse('whatsapp://send?text=$encoded'),
      Uri.parse('https://wa.me/?text=$encoded'),
      Uri.parse('https://api.whatsapp.com/send?text=$encoded'),
    ];
    return _launchCandidates(candidates, fallbackMessage: text);
  }

  /// Shares an image file via the system share sheet (WhatsApp appears if installed).
  static Future<bool> shareImageFile(String filePath, {String? text}) async {
    final path = filePath.trim();
    if (path.isEmpty) return false;
    final file = File(path);
    if (!file.existsSync()) {
      AppLog.d(_tag, 'shareImageFile missing path=$path');
      return false;
    }
    try {
      final result = await Share.shareXFiles(
        [XFile(path, mimeType: _mimeForPath(path))],
        text: text,
      );
      final ok = result.status != ShareResultStatus.dismissed;
      AppLog.d(_tag, 'shareImageFile status=${result.status}');
      return ok;
    } catch (e) {
      AppLog.e(_tag, 'shareImageFile failed', e);
      return false;
    }
  }

  static String _mimeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }

  static Future<bool> _launchCandidates(
    List<Uri> candidates, {
    required String fallbackMessage,
  }) async {
    for (final uri in candidates) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          AppLog.d(_tag, 'launchUrl OK scheme=${uri.scheme}');
          return true;
        }
      } catch (e) {
        AppLog.e(_tag, 'launchUrl failed scheme=${uri.scheme}', e);
      }
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
        if (launched) {
          AppLog.d(_tag, 'launchUrl platformDefault OK scheme=${uri.scheme}');
          return true;
        }
      } catch (e) {
        AppLog.e(_tag, 'platformDefault failed scheme=${uri.scheme}', e);
      }
    }

    try {
      // Last resort: share sheet (WhatsApp appears if installed).
      final result = await Share.share(fallbackMessage);
      final ok = result.status != ShareResultStatus.dismissed;
      AppLog.d(_tag, 'Share sheet status=${result.status}');
      return ok;
    } catch (e) {
      AppLog.e(_tag, 'Share sheet failed', e);
      return false;
    }
  }
}
