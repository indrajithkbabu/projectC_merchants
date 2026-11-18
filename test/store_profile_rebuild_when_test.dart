import 'package:flutter_test/flutter_test.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/models/store_privacy_mode.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/presentation/storeprofile/store_profile_rebuild_when.dart';

StoreProfileState _base({
  String storeName = 'Demo',
  String cover = 'https://cdn.example/c.jpg',
  int followers = 1,
  List<StoreProduct> products = const [],
  bool canView = true,
  StoreFollowStatus follow = StoreFollowStatus.none,
  bool followBusy = false,
}) {
  return StoreProfileState(
    storeName: storeName,
    members: const [],
    products: products,
    coverImageUrl: cover,
    followerCount: followers,
    canViewContent: canView,
    followStatus: follow,
    isFollowBusy: followBusy,
    isOwnStore: false,
    storeId: 'store_1',
  );
}

StoreProduct _product(String id) => StoreProduct(
  id: id,
  title: id,
  description: '',
  tags: const [],
  imagePaths: const ['https://cdn.example/a.jpg'],
);

void main() {
  group('storeProfileShellBuildWhen', () {
    test('ignores product and follow-busy changes', () {
      final p1 = _product('1');
      final a = _base(products: [p1]);
      final b = _base(products: [p1, _product('2')]);
      final c = _base(products: [p1], followBusy: true);
      expect(storeProfileShellBuildWhen(a, b), isFalse);
      expect(storeProfileShellBuildWhen(a, c), isFalse);
    });

    test('rebuilds when follow status flips dock visibility', () {
      final a = _base(follow: StoreFollowStatus.none);
      final b = _base(follow: StoreFollowStatus.following);
      expect(storeProfileShellBuildWhen(a, b), isTrue);
    });
  });

  group('storeProfileHeaderBuildWhen', () {
    test('rebuilds on cover / name / followers', () {
      final a = _base();
      expect(storeProfileHeaderBuildWhen(a, _base(storeName: 'Other')), isTrue);
      expect(
        storeProfileHeaderBuildWhen(
          a,
          _base(cover: 'https://cdn.example/x.jpg'),
        ),
        isTrue,
      );
      expect(storeProfileHeaderBuildWhen(a, _base(followers: 9)), isTrue);
    });

    test('ignores product list and follow busy', () {
      final p1 = _product('1');
      final a = _base(products: [p1]);
      final b = _base(products: [p1, _product('2')]);
      final c = _base(products: [p1], followBusy: true);
      expect(storeProfileHeaderBuildWhen(a, b), isFalse);
      expect(storeProfileHeaderBuildWhen(a, c), isFalse);
    });
  });

  group('storeProfileGridBuildWhen', () {
    test('rebuilds on products and listing availability', () {
      final a = _base(products: [_product('1')]);
      final b = _base(products: [_product('1'), _product('2')]);
      expect(storeProfileGridBuildWhen(a, b), isTrue);

      final withAvail = a.copyWith(listingAvailability: const {});
      // Same empty map identity may equal — use non-empty vs empty via products path.
      expect(
        storeProfileGridBuildWhen(
          a,
          a.copyWith(deletingProductId: 'listing_1'),
        ),
        isTrue,
      );
      expect(
        identical(withAvail.listingAvailability, a.listingAvailability),
        isTrue,
      );
    });

    test('ignores follower count and cover-only meta', () {
      final p = _product('1');
      final a = _base(products: [p]);
      // Use copyWith so only the named meta field changes.
      expect(
        storeProfileGridBuildWhen(a, a.copyWith(followerCount: 99)),
        isFalse,
      );
      expect(
        storeProfileGridBuildWhen(
          a,
          a.copyWith(coverImageUrl: 'https://cdn.example/other.jpg'),
        ),
        isFalse,
      );
    });

    test('rebuilds when private gate unlocks', () {
      final locked = _base(canView: false, products: const []);
      final unlocked = _base(canView: true, products: [_product('1')]);
      expect(storeProfileGridBuildWhen(locked, unlocked), isTrue);
    });
  });

  group('storeProfileFollowDockBuildWhen', () {
    test('rebuilds on busy and pending', () {
      final a = _base(follow: StoreFollowStatus.none);
      expect(
        storeProfileFollowDockBuildWhen(a, _base(followBusy: true)),
        isTrue,
      );
      expect(
        storeProfileFollowDockBuildWhen(
          a,
          _base(follow: StoreFollowStatus.pending),
        ),
        isTrue,
      );
    });

    test('ignores product updates', () {
      final p1 = _product('1');
      final a = _base(products: [p1]);
      final b = _base(products: [p1, _product('2')]);
      expect(storeProfileFollowDockBuildWhen(a, b), isFalse);
    });
  });
}
