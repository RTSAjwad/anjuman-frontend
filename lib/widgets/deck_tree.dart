import '../models/deck.dart';

/// Builds a nested tree of [DeckResponse] from a flat list using [parentId].
/// Returns top-level nodes (those with [parentId] == null), each with
/// their children recursively attached.
List<DeckNode> buildDeckTree(List<DeckResponse> decks) {
  List<DeckNode> buildChildren(int? parentId) {
    return decks
        .where((d) => d.parentId == parentId)
        .map((d) => DeckNode(
              deck: d,
              children: buildChildren(d.id),
            ))
        .toList();
  }

  return buildChildren(null);
}

/// A node in a deck tree, holding a deck and its children.
class DeckNode {
  final DeckResponse deck;
  final List<DeckNode> children;

  const DeckNode({required this.deck, required this.children});

  /// Walks the tree depth-first and returns a flat list of (deck, depth) pairs.
  List<(DeckResponse deck, int depth)> flatten() {
    final result = <(DeckResponse, int)>[];
    void walk(List<DeckNode> nodes, int depth) {
      for (final node in nodes) {
        result.add((node.deck, depth));
        walk(node.children, depth + 1);
      }
    }

    walk([this], 0);
    return result;
  }
}
