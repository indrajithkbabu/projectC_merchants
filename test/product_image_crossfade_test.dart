import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_c/helper/product_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap({
    required Widget child,
    Size size = const Size(120, 120),
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: size.width, height: size.height, child: child),
        ),
      ),
    );
  }

  Widget ph([Key? key]) => ColoredBox(
        key: key ?? const ValueKey('placeholder'),
        color: const Color(0xFF888888),
      );

  Widget img([Key? key, Color color = const Color(0xFF00AA00)]) => ColoredBox(
        key: key ?? const ValueKey('image'),
        color: color,
      );

  group('ProductImageCrossfade', () {
    test('fade duration is within I4 150–200 ms target', () {
      expect(
        ProductImageCrossfade.fadeDuration.inMilliseconds,
        inInclusiveRange(150, 200),
      );
    });

    testWidgets('ThumbHash/placeholder visible before image is ready', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          child: ProductImageCrossfade(
            image: img(),
            placeholder: ph(),
            imageReady: false,
          ),
        ),
      );

      expect(find.byKey(const ValueKey('placeholder')), findsOneWidget);
      expect(find.byKey(const ValueKey('image')), findsOneWidget);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0.0,
      );
    });

    testWidgets('successful load crossfades placeholder → image', (
      tester,
    ) async {
      var ready = false;
      await tester.pumpWidget(
        wrap(
          child: StatefulBuilder(
            builder: (context, setState) {
              return GestureDetector(
                onTap: () => setState(() => ready = true),
                child: ProductImageCrossfade(
                  image: img(),
                  placeholder: ph(),
                  imageReady: ready,
                ),
              );
            },
          ),
        ),
      );

      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0.0,
      );

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1.0,
      );

      await tester.pump(ProductImageCrossfade.fadeDuration * 0.5);
      expect(find.byKey(const ValueKey('placeholder')), findsOneWidget);
      expect(find.byKey(const ValueKey('image')), findsOneWidget);

      await tester.pump(ProductImageCrossfade.fadeDuration);
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(const ValueKey('placeholder')), findsNothing);
      expect(find.byKey(const ValueKey('image')), findsOneWidget);
    });

    testWidgets('instant/cached path has no blank frame and skips fade stack', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          child: ProductImageCrossfade(
            image: img(),
            placeholder: ph(),
            imageReady: true,
            instant: true,
          ),
        ),
      );

      expect(find.byKey(const ValueKey('image')), findsOneWidget);
      expect(find.byKey(const ValueKey('placeholder')), findsNothing);
      expect(find.byType(AnimatedOpacity), findsNothing);
    });

    testWidgets('same-URL rebuild does not restart completed transition', (
      tester,
    ) async {
      var ready = false;
      var tick = 0;
      await tester.pumpWidget(
        wrap(
          size: const Size(200, 280),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  Text('tick=$tick'),
                  Expanded(
                    child: ProductImageCrossfade(
                      image: img(),
                      placeholder: ph(),
                      imageReady: ready,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => ready = true),
                    child: const Text('ready'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => tick++),
                    child: const Text('rebuild'),
                  ),
                ],
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('ready'));
      await tester.pump();
      await tester.pump(ProductImageCrossfade.fadeDuration);
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(AnimatedOpacity), findsNothing);

      await tester.tap(find.text('rebuild'));
      await tester.pump();
      expect(find.byType(AnimatedOpacity), findsNothing);
      expect(find.byKey(const ValueKey('image')), findsOneWidget);
      expect(find.byKey(const ValueKey('placeholder')), findsNothing);
    });

    testWidgets('URL/identity change does not keep previous image as sole paint', (
      tester,
    ) async {
      var url = 'a';
      await tester.pumpWidget(
        wrap(
          child: StatefulBuilder(
            builder: (context, setState) {
              return GestureDetector(
                onTap: () => setState(() => url = 'b'),
                child: ProductImageCrossfade(
                  key: ValueKey(url),
                  image: img(
                    ValueKey('image-$url'),
                    url == 'a'
                        ? const Color(0xFF00AA00)
                        : const Color(0xFF0000AA),
                  ),
                  placeholder: ph(ValueKey('ph-$url')),
                  imageReady: false,
                ),
              );
            },
          ),
        ),
      );

      expect(find.byKey(const ValueKey('image-a')), findsOneWidget);
      await tester.tap(find.byType(GestureDetector));
      await tester.pump();
      expect(find.byKey(const ValueKey('image-a')), findsNothing);
      expect(find.byKey(const ValueKey('ph-b')), findsOneWidget);
      expect(find.byKey(const ValueKey('image-b')), findsOneWidget);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0.0,
      );
    });

    testWidgets('not-ready keeps placeholder (decode-failure fallback host)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          child: ProductImageCrossfade(
            image: const SizedBox.shrink(key: ValueKey('empty-image')),
            placeholder: ph(),
            imageReady: false,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('placeholder')), findsOneWidget);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0.0,
      );
    });

    testWidgets('disposal during pending reveal is safe', (tester) async {
      await tester.pumpWidget(
        wrap(
          child: ProductImageCrossfade(
            image: img(),
            placeholder: ph(),
            imageReady: false,
          ),
        ),
      );
      await tester.pumpWidget(
        wrap(
          child: ProductImageCrossfade(
            image: img(),
            placeholder: ph(),
            imageReady: true,
          ),
        ),
      );
      await tester.pump(ProductImageCrossfade.fadeDuration * 0.25);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(ProductImageCrossfade.fadeDuration);
    });

    testWidgets('cacheWidth identity is orthogonal — distinct keys coexist', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          size: const Size(240, 120),
          child: Row(
            children: [
              Expanded(
                child: ProductImageCrossfade(
                  key: const ValueKey('url@120'),
                  image: img(const ValueKey('img-120')),
                  placeholder: ph(const ValueKey('ph-120')),
                  imageReady: true,
                  instant: true,
                ),
              ),
              Expanded(
                child: ProductImageCrossfade(
                  key: const ValueKey('url@240'),
                  image: img(const ValueKey('img-240')),
                  placeholder: ph(const ValueKey('ph-240')),
                  imageReady: false,
                ),
              ),
            ],
          ),
        ),
      );

      expect(find.byKey(const ValueKey('img-120')), findsOneWidget);
      expect(find.byKey(const ValueKey('ph-240')), findsOneWidget);
      expect(find.byKey(const ValueKey('img-240')), findsOneWidget);
    });

    testWidgets('crossfade setState does not rebuild parent grid host', (
      tester,
    ) async {
      var parentBuilds = 0;
      var ready = false;

      await tester.pumpWidget(
        wrap(
          size: const Size(200, 280),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  TextButton(
                    onPressed: () => setState(() => ready = true),
                    child: const Text('ready'),
                  ),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        parentBuilds++;
                        return ProductImageCrossfade(
                          image: img(),
                          placeholder: ph(),
                          imageReady: ready,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );

      final buildsBeforeReady = parentBuilds;
      await tester.tap(find.text('ready'));
      await tester.pump();
      expect(parentBuilds, buildsBeforeReady + 1);
      final buildsAfterReady = parentBuilds;

      await tester.pump(ProductImageCrossfade.fadeDuration);
      await tester.pump(const Duration(milliseconds: 16));
      expect(parentBuilds, buildsAfterReady);
    });
  });

  group('ProductMediaImage fallbacks', () {
    testWidgets('empty path keeps error/broken fallback (no blank)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          child: const ProductMediaImage(
            path: '',
            error: ColoredBox(
              key: ValueKey('err'),
              color: Color(0xFFFF0000),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('err')), findsOneWidget);
    });
  });
}
