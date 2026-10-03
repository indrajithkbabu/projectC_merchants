import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fast_thumbhash/fast_thumbhash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:project_c/helper/colors.dart';

/// File-based image cache (JSON index) — avoids sqflite / MissingPluginException
/// when the default [DefaultCacheManager] DB channel is not registered yet.
class CatalogImageCache {
  CatalogImageCache._();

  static final CacheManager instance = CacheManager(
    Config(
      'catalogImages',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 400,
      repo: JsonCacheInfoRepository(databaseName: 'catalogImages'),
    ),
  );

  /// Drops disk + memory image cache (logout / delete account).
  static Future<void> clearAll() async {
    try {
      await instance.emptyCache();
    } catch (_) {}
  }

  /// Warm disk cache for [urls] so collage tiles paint without pop-in.
  static Future<void> precacheUrls(
    Iterable<String> urls, {
    int concurrency = 6,
  }) async {
    final pending =
        urls
            .map((u) => u.trim())
            .where((u) => u.startsWith('http://') || u.startsWith('https://'))
            .toSet()
            .toList(growable: false);
    if (pending.isEmpty) return;

    for (var i = 0; i < pending.length; i += concurrency) {
      final end =
          i + concurrency > pending.length ? pending.length : i + concurrency;
      await Future.wait([
        for (final url in pending.sublist(i, end))
          instance.getSingleFile(url).then<void>((_) {}).catchError((_) {}),
      ]);
    }
  }
}

/// Shared helpers for product/collection media (local path or remote URL).
class ProductImagePaths {
  ProductImagePaths._();

  static bool isNetwork(String path) {
    final value = path.trim();
    return value.startsWith('http://') || value.startsWith('https://');
  }

  static bool isDisplayable(String path) {
    final value = path.trim();
    if (value.isEmpty) return false;
    if (isNetwork(value)) return true;
    return File(value).existsSync();
  }

  static List<String> displayable(List<String> paths) {
    return paths.where(isDisplayable).toList(growable: false);
  }

  /// Local [File] for sharing: existing path, or disk-cached network URL.
  static Future<File?> resolveLocalFile(String path) async {
    final value = path.trim();
    if (value.isEmpty) return null;
    if (isNetwork(value)) {
      try {
        return await CatalogImageCache.instance.getSingleFile(value);
      } catch (_) {
        return null;
      }
    }
    final file = File(value);
    if (!file.existsSync()) return null;
    return file;
  }

  static ImageProvider? provider(String path) {
    final value = path.trim();
    if (value.isEmpty) return null;
    if (isNetwork(value)) {
      return CachedNetworkImageProvider(
        value,
        cacheManager: CatalogImageCache.instance,
      );
    }
    final file = File(value);
    if (!file.existsSync()) return null;
    return FileImage(file);
  }

  /// Decode a base64 ThumbHash into an [ImageProvider], or null on failure.
  ///
  /// Builds PNG bytes eagerly and validates them so a bad hash never reaches
  /// [MemoryImage] (which would throw "Could not decompress image" async).
  static ImageProvider? thumbhashProvider(String? thumbhashBase64) {
    final raw = thumbhashBase64?.trim() ?? '';
    if (raw.isEmpty) return null;
    try {
      // Copy into a tight buffer — ThumbHash.fromBytes uses
      // `bytes.buffer.asUint8List()` which can include trailing junk.
      final decoded = base64Decode(base64.normalize(raw));
      if (decoded.length < 5) return null;
      final hash = ThumbHash.fromBytes(Uint8List.fromList(decoded));
      final png = hash.toPngBytes();
      if (png.length < 8 ||
          png[0] != 0x89 ||
          png[1] != 0x50 ||
          png[2] != 0x4E ||
          png[3] != 0x47) {
        return null;
      }
      return MemoryImage(png);
    } catch (_) {
      return null;
    }
  }

  /// Average color from a ThumbHash — safe solid fill when PNG decode is risky.
  static Color? thumbhashAverageColor(String? thumbhashBase64) {
    final raw = thumbhashBase64?.trim() ?? '';
    if (raw.isEmpty) return null;
    try {
      final decoded = base64Decode(base64.normalize(raw));
      if (decoded.length < 5) return null;
      return ThumbHash.fromBytes(
        Uint8List.fromList(decoded),
      ).toAverageColor();
    } catch (_) {
      return null;
    }
  }
}

/// Renders a local file or remote URL with disk+memory cache for network URLs.
///
/// When [thumbhash] is present, it paints instantly as the network placeholder.
class ProductMediaImage extends StatelessWidget {
  const ProductMediaImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.thumbhash,
    this.error,
  });

  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;
  final String? thumbhash;
  final Widget? error;

  @override
  Widget build(BuildContext context) {
    final value = path.trim();
    if (value.isEmpty) return error ?? _broken();

    if (ProductImagePaths.isNetwork(value)) {
      // Custom file-backed cache + gaplessPlayback → no sqflite, no flicker.
      ImageProvider provider = CachedNetworkImageProvider(
        value,
        cacheManager: CatalogImageCache.instance,
      );
      final finiteWidth = width != null && width!.isFinite ? width! : null;
      if (finiteWidth != null) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        provider = ResizeImage.resizeIfNeeded(
          (finiteWidth * dpr).round(),
          null,
          provider,
        );
      }
      final placeholder = ProductImagePaths.thumbhashProvider(thumbhash);
      final averageColor = ProductImagePaths.thumbhashAverageColor(thumbhash);
      return Image(
        key: ValueKey(value),
        image: provider,
        fit: fit,
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (placeholder != null)
                Image(
                  image: placeholder,
                  fit: fit,
                  errorBuilder:
                      (_, __, ___) => ColoredBox(
                        color: averageColor ?? AppColors.surfaceSecondary,
                      ),
                )
              else
                ColoredBox(
                  color: averageColor ?? AppColors.surfaceSecondary,
                ),
              AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: child,
              ),
            ],
          );
        },
        errorBuilder: (_, __, ___) => error ?? _broken(),
      );
    }

    final file = File(value);
    if (!file.existsSync()) return error ?? _broken();

    return Image.file(
      file,
      fit: fit,
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => error ?? _broken(),
    );
  }

  static Widget _broken() {
    return const ColoredBox(
      color: AppColors.surfaceSecondary,
      child: Icon(
        Icons.broken_image_outlined,
        color: AppColors.textSecondary,
      ),
    );
  }
}
