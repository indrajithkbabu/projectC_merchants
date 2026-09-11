import 'package:project_c/bloc/team/team_bloc.dart';
import 'package:project_c/models/store_channel.dart';
import 'package:project_c/models/store_product.dart';

/// In-memory merchant session for the current demo phase (no backend yet).
class MerchantStoreSession {
  MerchantStoreSession._();

  static final MerchantStoreSession instance = MerchantStoreSession._();

  String storeName = '';
  String storeHandle = '';
  List<TeamMember> members = const [];
  List<StoreProduct> products = [];

  bool get isReady => storeName.trim().isNotEmpty;

  String get storeLink {
    final handle =
        storeHandle.isNotEmpty
            ? storeHandle
            : storeName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return '$handle.jewelflow.app';
  }

  StoreChannel get asChannel => StoreChannel(
    id: 'my_store',
    name: storeName,
    handle:
        storeHandle.isNotEmpty
            ? storeHandle
            : storeName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
    avatarColor: 0xFF2AABEE,
    products: List<StoreProduct>.from(products),
    isOwn: true,
  );

  void bootstrap({
    required String storeName,
    List<TeamMember> members = const [],
  }) {
    final firstTime = !isReady;
    this.storeName = storeName.trim().isEmpty ? 'My Store' : storeName.trim();
    storeHandle = this.storeName.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '-',
    );
    this.members = List<TeamMember>.from(members);
    if (firstTime) {
      products = [];
    }
  }

  void addProduct(StoreProduct product) {
    products = [product, ...products];
  }

  void addProducts(List<StoreProduct> incoming) {
    // Avoid duplicates by id when re-importing.
    final existingIds = products.map((p) => p.id).toSet();
    final unique =
        incoming.where((p) => !existingIds.contains(p.id)).toList();
    products = [...unique, ...products];
  }

  void replaceProducts(List<StoreProduct> next) {
    products = List<StoreProduct>.from(next);
  }
}
