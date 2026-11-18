/// Session-scoped viewer like flags for catalog products.
///
/// Browse / list seeds can stay stale after a details like toggle. Details
/// hydrate prefers these overrides so reopen / swipe does not wipe chrome.
class ViewerProductFlags {
  ViewerProductFlags._();

  static final ViewerProductFlags instance = ViewerProductFlags._();

  final Set<String> _liked = <String>{};
  final Set<String> _unliked = <String>{};

  void markLiked(String productId, {required bool liked}) {
    final id = productId.trim();
    if (id.isEmpty) return;
    if (liked) {
      _liked.add(id);
      _unliked.remove(id);
    } else {
      _unliked.add(id);
      _liked.remove(id);
    }
  }

  /// Explicit session override, or null when none.
  bool? likedOverride(String productId) {
    final id = productId.trim();
    if (id.isEmpty) return null;
    if (_unliked.contains(id)) return false;
    if (_liked.contains(id)) return true;
    return null;
  }

  void invalidate() {
    _liked.clear();
    _unliked.clear();
  }
}
