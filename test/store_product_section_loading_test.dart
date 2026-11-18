import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_c/models/product_view_mode.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_grid_shimmer.dart';

/// Batch I5 — cold loader must match the product grid layout.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget sliver) {
    return MaterialApp(
      home: Scaffold(
        body: CustomScrollView(slivers: [sliver]),
      ),
    );
  }

  testWidgets('group mode uses 2-col card skeleton matching UI', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(
        const StoreProductGridShimmer(
          viewMode: ProductViewMode.group,
          itemCount: 6,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(StoreProductGridShimmer), findsOneWidget);
    expect(find.byType(SliverGrid), findsOneWidget);
    // Viewport builds visible cells; expect the group card skeleton type.
    expect(find.byType(ProductUploadShimmerCard), findsWidgets);
    expect(find.byType(ProductUploadShimmerTile), findsNothing);
  });

  testWidgets('single mode uses full-width card skeleton', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(
        const StoreProductGridShimmer(
          viewMode: ProductViewMode.single,
          itemCount: 4,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.byType(ProductUploadShimmerCard), findsWidgets);
    expect(find.byType(ProductUploadShimmerTile), findsNothing);
  });

  testWidgets('gallery mode uses mosaic tile skeleton', (tester) async {
    await tester.pumpWidget(
      wrap(
        const StoreProductGridShimmer(
          viewMode: ProductViewMode.gallery,
          galleryColumns: 4,
          itemCount: 12,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.byType(ProductUploadShimmerTile), findsWidgets);
    expect(find.byType(ProductUploadShimmerCard), findsNothing);
  });
}
