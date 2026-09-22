import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Short in-memory TTL so repeated `.get()` calls in the same session
/// do not each bill a Firestore read. Live listeners are unaffected.
class FirestoreReadCache {
  FirestoreReadCache._();

  static const Duration ttl = Duration(seconds: 60);
  static final Map<String, _CacheEntry> _entries = {};

  static T? get<T>(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _entries.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  static void set(String key, Object value, {Duration? ttl}) {
    _entries[key] = _CacheEntry(
      value,
      DateTime.now().add(ttl ?? FirestoreReadCache.ttl),
    );
  }

  static Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetch, {
    Duration? ttl,
  }) async {
    final cached = get<T>(key);
    if (cached != null) return cached;
    final value = await fetch();
    set(key, value as Object, ttl: ttl);
    return value;
  }

  static void invalidate(String key) => _entries.remove(key);
  static void clear() => _entries.clear();
}

class _CacheEntry {
  const _CacheEntry(this.value, this.expiresAt);
  final Object value;
  final DateTime expiresAt;
}

/// One billed Firestore snapshot listener per [key], shared by every
/// widget that subscribes. Multiple StreamBuilders get the same live
/// stream — only 1 Firestore read is billed.
class FirestoreListenCache {
  FirestoreListenCache._();

  static final Map<String, _SharedQueryListen> _queries = {};
  static final Map<String, _SharedDocListen> _docs = {};

  static Stream<QuerySnapshot<Map<String, dynamic>>> query(
    String key,
    Query<Map<String, dynamic>> query,
  ) {
    final existing = _queries[key];
    if (existing != null) return existing.stream;
    final shared = _SharedQueryListen(key, query);
    _queries[key] = shared;
    return shared.stream;
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> doc(
    String key,
    DocumentReference<Map<String, dynamic>> ref,
  ) {
    final existing = _docs[key];
    if (existing != null) return existing.stream;
    final shared = _SharedDocListen(key, ref);
    _docs[key] = shared;
    return shared.stream;
  }

  static void removeQuery(String key) => _queries.remove(key);
  static void removeDoc(String key) => _docs.remove(key);
}

/// Wraps a single Firestore Query listener and exposes it as a
/// broadcast stream. The Firestore subscription is kept alive as long
/// as there is at least one subscriber.
class _SharedQueryListen {
  _SharedQueryListen(this.key, this.query) {
    _controller = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast(
      onListen: _onListen,
      onCancel: _onCancel,
    );
  }

  final String key;
  final Query<Map<String, dynamic>> query;
  late final StreamController<QuerySnapshot<Map<String, dynamic>>> _controller;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  Stream<QuerySnapshot<Map<String, dynamic>>> get stream => _controller.stream;

  void _onListen() {
    // Start the real Firestore subscription when first subscriber arrives.
    _sub ??= query.snapshots().listen(
      _controller.add,
      onError: _controller.addError,
    );
  }

  void _onCancel() {
    // Cancel the Firestore subscription and clean up when all subscribers leave.
    _sub?.cancel();
    _sub = null;
    FirestoreListenCache.removeQuery(key);
  }
}

/// Same as [_SharedQueryListen] but for a single Firestore document.
class _SharedDocListen {
  _SharedDocListen(this.key, this.ref) {
    _controller = StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast(
      onListen: _onListen,
      onCancel: _onCancel,
    );
  }

  final String key;
  final DocumentReference<Map<String, dynamic>> ref;
  late final StreamController<DocumentSnapshot<Map<String, dynamic>>> _controller;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  Stream<DocumentSnapshot<Map<String, dynamic>>> get stream => _controller.stream;

  void _onListen() {
    _sub ??= ref.snapshots().listen(
      _controller.add,
      onError: _controller.addError,
    );
  }

  void _onCancel() {
    _sub?.cancel();
    _sub = null;
    FirestoreListenCache.removeDoc(key);
  }
}
