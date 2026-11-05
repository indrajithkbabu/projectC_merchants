import 'package:flutter_test/flutter_test.dart';
import 'package:project_c/bloc/bulk_upload/bulk_upload_bloc.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/models/catalog/catalog_product_models.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/presentation/add_store_product/compose_product_draft.dart';
import 'package:project_c/services/catalog_direct_upload_service.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/storage/session_storage.dart';
import 'package:project_c/webservice/catalog_api_client.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';

/// Filter logcat / Flutter console: `EditRefine`
///
/// Cases: compose-first Edit / Select→Edit apply specs+tags then save,
/// without opening the preview grid.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProductSpec validSpec({String category = 'ring', double weight = 8.5}) {
    return ProductSpec(
      metalType: const ['gold'],
      purity: '92',
      purityMode: FieldMode.fixed,
      wastageMode: FieldMode.fixed,
      wastagePercent: 4,
      sizeMode: SizeMode.free,
      weightMode: WeightMode.fixed,
      grossMin: weight,
      category: category,
    );
  }

  CollectionDetail detailWithPhotos(List<String> ids) {
    final photos = [
      for (final id in ids)
        CatalogPhoto(
          id: id,
          width: 100,
          height: 100,
          url: 'https://example.com/$id.jpg',
        ),
    ];
    return CollectionDetail(
      id: 'listing_1',
      name: 'Gold set',
      tag: 'bridal,festive',
      revision: 3,
      photoCount: photos.length,
      photos: photos,
      mainGroupPhotos: photos,
      // Jewel listing → product PATCH path (stubbed); no subgroup create.
      productSpecsById: {
        for (final id in ids) id: validSpec(),
      },
      defaultsSpec: validSpec(),
    );
  }

  CatalogSession testSession() {
    final storage = SessionStorage();
    return CatalogSession(
      storage: storage,
      apiClient: CatalogApiClient(sessionStorage: storage),
    );
  }

  BulkUploadBloc editBloc({
    required List<String> ids,
    List<String> selected = const [],
    required _FakeCollectionRepository repo,
  }) {
    final detail = detailWithPhotos(ids);
    repo.seed(detail);
    return BulkUploadBloc.fromCollectionDetail(
      detail: detail,
      storeId: 'store_1',
      initiallySelectedIds: selected,
      collectionRepository: repo,
      directUploadService: CatalogDirectUploadService(
        collectionRepository: repo,
      ),
      session: testSession(),
    );
  }

  group('BulkUploadComposeRefineSubmitted (EditRefine)', () {
    test('skips when not in edit mode', () async {
      final repo = _FakeCollectionRepository();
      final bloc = BulkUploadBloc(
        images: const [],
        collectionRepository: repo,
        directUploadService: CatalogDirectUploadService(
          collectionRepository: repo,
        ),
        session: testSession(),
      );
      addTearDown(bloc.close);

      bloc.add(
        BulkUploadComposeRefineSubmitted(
          itemIds: const ['a'],
          drafts: [ComposePhotoDraft(spec: validSpec(), tags: const ['x'])],
          imagePaths: const ['https://example.com/a.jpg'],
        ),
      );
      await pumpEventQueue();
      expect(bloc.state.isEditMode, isFalse);
      expect(bloc.state.shouldPopWithResult, isFalse);
      expect(repo.updateCollectionCalls, 0);
    });

    test('single-item apply updates specs + tags then saves', () async {
      final repo = _FakeCollectionRepository();
      final bloc = editBloc(
        ids: const ['p1'],
        selected: const ['p1'],
        repo: repo,
      );
      addTearDown(bloc.close);

      expect(bloc.state.isEditMode, isTrue);

      final nextSpec = validSpec(category: 'necklace', weight: 12);
      bloc.add(
        BulkUploadComposeRefineSubmitted(
          itemIds: const ['p1'],
          drafts: [
            ComposePhotoDraft(
              spec: nextSpec,
              tags: const ['wedding', 'gold'],
            ),
          ],
          imagePaths: const ['https://example.com/p1.jpg'],
          applyToAll: true,
          title: 'Necklace',
          description: 'Bridal piece',
        ),
      );

      final done = await bloc.stream.firstWhere(
        (s) => s.shouldPopWithResult || (s.errorMessage?.isNotEmpty ?? false),
      );

      expect(done.errorMessage, isNull);
      expect(done.shouldPopWithResult, isTrue);
      expect(done.items.single.spec.category, 'necklace');
      expect(done.items.single.spec.grossMin, 12);
      expect(done.tags, containsAll(['wedding', 'gold']));
      expect(done.groupTitle, 'Necklace');
      expect(done.description, 'Bridal piece');
      expect(repo.lastUpdateTag, 'wedding, gold');
      expect(repo.lastUpdateName, 'Necklace');
      expect(repo.lastUpdateDescription, 'Bridal piece');
      expect(repo.updateCollectionCalls, greaterThanOrEqualTo(1));
      expect(done.publishedProduct, isNotNull);
      expect(done.publishedProduct!.title, 'Necklace');
    });

    test('multi applyToAll copies first draft spec to all selected', () async {
      final repo = _FakeCollectionRepository();
      final bloc = editBloc(
        ids: const ['p1', 'p2'],
        selected: const ['p1', 'p2'],
        repo: repo,
      );
      addTearDown(bloc.close);

      final shared = validSpec(category: 'bangle', weight: 20);
      bloc.add(
        BulkUploadComposeRefineSubmitted(
          itemIds: const ['p1', 'p2'],
          drafts: [
            ComposePhotoDraft(spec: shared, tags: const ['shared']),
            ComposePhotoDraft(
              spec: validSpec(category: 'ring', weight: 1),
              tags: const ['ignored_when_apply_all'],
            ),
          ],
          imagePaths: const [
            'https://example.com/p1.jpg',
            'https://example.com/p2.jpg',
          ],
          applyToAll: true,
        ),
      );

      final done = await bloc.stream.firstWhere(
        (s) => s.shouldPopWithResult || (s.errorMessage?.isNotEmpty ?? false),
      );

      expect(done.shouldPopWithResult, isTrue);
      expect(done.items.every((i) => i.spec.category == 'bangle'), isTrue);
      expect(done.items.every((i) => i.spec.grossMin == 20), isTrue);
      expect(done.tags, contains('shared'));
    });

    test('per-item drafts when applyToAll is false', () async {
      final repo = _FakeCollectionRepository();
      final bloc = editBloc(
        ids: const ['p1', 'p2'],
        selected: const ['p1', 'p2'],
        repo: repo,
      );
      addTearDown(bloc.close);

      bloc.add(
        BulkUploadComposeRefineSubmitted(
          itemIds: const ['p1', 'p2'],
          drafts: [
            ComposePhotoDraft(
              spec: validSpec(category: 'ring', weight: 5),
              tags: const ['a'],
            ),
            ComposePhotoDraft(
              spec: validSpec(category: 'pendant', weight: 9),
              tags: const ['b'],
            ),
          ],
          imagePaths: const [
            'https://example.com/p1.jpg',
            'https://example.com/p2.jpg',
          ],
          applyToAll: false,
        ),
      );

      final done = await bloc.stream.firstWhere(
        (s) => s.shouldPopWithResult || (s.errorMessage?.isNotEmpty ?? false),
      );

      expect(done.shouldPopWithResult, isTrue);
      expect(done.items.firstWhere((i) => i.id == 'p1').spec.category, 'ring');
      expect(
        done.items.firstWhere((i) => i.id == 'p2').spec.category,
        'pendant',
      );
      expect(done.tags, containsAll(['a', 'b']));
    });
  });

  group('BulkUploadTagsReplaced', () {
    test('replaces tag list on edit hydrate', () async {
      final repo = _FakeCollectionRepository();
      final bloc = editBloc(ids: const ['p1'], repo: repo);
      addTearDown(bloc.close);

      expect(bloc.state.tags, containsAll(['bridal', 'festive']));
      bloc.add(const BulkUploadTagsReplaced(['new', 'tag']));
      await pumpEventQueue();
      expect(bloc.state.tags, ['new', 'tag']);
    });
  });

}

class _FakeCollectionRepository implements CollectionRepository {
  late CollectionDetail _detail;
  int updateCollectionCalls = 0;
  String? lastUpdateTag;
  String? lastUpdateName;
  String? lastUpdateDescription;

  void seed(CollectionDetail detail) {
    _detail = detail;
  }

  @override
  Future<CollectionDetail> fetchCollection({
    required String storeId,
    required String listingId,
  }) async =>
      _detail;

  @override
  Future<CollectionMutation> updateCollection({
    required String storeId,
    required String listingId,
    required int revision,
    String? name,
    String? tag,
    String? description,
    Map<String, dynamic>? specifications,
    bool? usePrecisionTag,
  }) async {
    updateCollectionCalls++;
    lastUpdateTag = tag;
    lastUpdateName = name;
    lastUpdateDescription = description;
    _detail = CollectionDetail(
      id: _detail.id,
      name: name?.trim().isNotEmpty == true ? name!.trim() : _detail.name,
      tag: tag ?? _detail.tag,
      description: description ?? _detail.description,
      revision: revision + 1,
      photoCount: _detail.photoCount,
      photos: _detail.photos,
      mainGroupPhotos: _detail.mainGroupPhotos,
      subGroups: _detail.subGroups,
      productSpecsById: _detail.productSpecsById,
      defaultsSpec: _detail.defaultsSpec,
      specifications: _detail.specifications,
    );
    return CollectionMutation(
      id: _detail.id,
      name: _detail.name,
      tag: _detail.tag,
      description: _detail.description,
      revision: _detail.revision,
    );
  }

  @override
  Future<CatalogProduct> updateProduct({
    required String productId,
    required Map<String, dynamic> body,
  }) async {
    return CatalogProduct(
      id: productId,
      storeId: 'store_1',
      title: 'item',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
