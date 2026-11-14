import 'package:flutter/foundation.dart';
import '../data/models/entity_link.dart';
import '../data/services/storage_service.dart';

class CrossModuleLinkProvider extends ChangeNotifier {
  final StorageService _storage;
  List<EntityLink> _links = [];

  CrossModuleLinkProvider(this._storage) {
    _links = _storage.loadEntityLinks();
  }

  List<EntityLink> get allLinks => List.unmodifiable(_links);

  /// Returns bidirectional linked references for any Nestin entity.
  List<LinkedEntityRef> linksFor(LinkEntityType type, String entityId) {
    final result = <LinkedEntityRef>[];
    for (final link in _links) {
      final ref = link.otherSideFor(type, entityId);
      if (ref != null) result.add(ref);
    }
    return result;
  }

  int countFor(LinkEntityType type, String entityId) {
    var count = 0;
    for (final link in _links) {
      if (link.connects(type, entityId)) count++;
    }
    return count;
  }

  Future<EntityLink?> addLink({
    required LinkEntityType sourceType,
    required String sourceId,
    required String sourceTitle,
    required LinkEntityType targetType,
    required String targetId,
    required String targetTitle,
    String relationship = 'related',
  }) async {
    if (sourceType == targetType && sourceId == targetId) {
      return null;
    }
    final alreadyExists = _links.any(
      (l) => l.matchesPair(sourceType, sourceId, targetType, targetId),
    );
    if (alreadyExists) {
      return null;
    }

    final link = EntityLink(
      sourceType: sourceType,
      sourceId: sourceId,
      sourceTitle: sourceTitle,
      targetType: targetType,
      targetId: targetId,
      targetTitle: targetTitle,
      relationship: relationship,
    );
    _links = [link, ..._links];
    await _storage.saveEntityLinks(_links);
    notifyListeners();
    return link;
  }

  Future<void> removeLink(String linkId) async {
    _links = _links.where((l) => l.id != linkId).toList();
    await _storage.saveEntityLinks(_links);
    notifyListeners();
  }

  Future<void> removeAllLinksFor(LinkEntityType type, String entityId) async {
    final next = _links.where((l) => !l.connects(type, entityId)).toList();
    if (next.length == _links.length) return;
    _links = next;
    await _storage.saveEntityLinks(_links);
    notifyListeners();
  }

  Future<void> syncEntityTitle(
    LinkEntityType type,
    String entityId,
    String newTitle,
  ) async {
    var changed = false;
    final updated = _links.map((link) {
      if (link.sourceType == type &&
          link.sourceId == entityId &&
          link.sourceTitle != newTitle) {
        changed = true;
        return EntityLink(
          id: link.id,
          sourceType: link.sourceType,
          sourceId: link.sourceId,
          sourceTitle: newTitle,
          targetType: link.targetType,
          targetId: link.targetId,
          targetTitle: link.targetTitle,
          relationship: link.relationship,
          createdAt: link.createdAt,
        );
      }
      if (link.targetType == type &&
          link.targetId == entityId &&
          link.targetTitle != newTitle) {
        changed = true;
        return EntityLink(
          id: link.id,
          sourceType: link.sourceType,
          sourceId: link.sourceId,
          sourceTitle: link.sourceTitle,
          targetType: link.targetType,
          targetId: link.targetId,
          targetTitle: newTitle,
          relationship: link.relationship,
          createdAt: link.createdAt,
        );
      }
      return link;
    }).toList();

    if (changed) {
      _links = updated;
      await _storage.saveEntityLinks(_links);
      notifyListeners();
    }
  }
}
