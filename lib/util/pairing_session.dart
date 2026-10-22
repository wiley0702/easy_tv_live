import 'dart:math';

class PairingSession {
  PairingSession({DateTime Function()? now}) : _now = now ?? DateTime.now {
    renew();
  }
  final DateTime Function() _now;
  final _random = Random.secure();
  final Map<String, ({String peer, DateTime expires})> _tokens = {};
  final Map<String, ({int count, DateTime until})> _failures = {};
  late String _code;
  late DateTime _expires;
  bool _closed = false;
  String get code {
    if (!_closed && !_now().isBefore(_expires)) renew();
    return _code;
  }

  void renew() {
    _code = _random.nextInt(1000000).toString().padLeft(6, '0');
    _expires = _now().add(const Duration(minutes: 5));
  }

  bool blocked(String peer) {
    final failure = _failures[peer];
    return failure != null && failure.count >= 5 && _now().isBefore(failure.until);
  }

  String? pair(String supplied, String peer) {
    if (_closed || blocked(peer)) return null;
    // Expiry invalidates the entered code even if the screen has not refreshed yet.
    if (!_now().isBefore(_expires)) {
      renew();
      return null;
    }
    if (supplied != _code) {
      final previous = _failures[peer];
      final count = previous != null && _now().isBefore(previous.until) ? previous.count + 1 : 1;
      _failures[peer] = (count: count, until: _now().add(const Duration(seconds: 30)));
      return null;
    }
    _failures.remove(peer);
    return issueToken(peer);
  }

  String issueToken(String peer) {
    if (_closed) throw StateError('Pairing session closed');
    _tokens.removeWhere((_, session) => !_now().isBefore(session.expires));
    if (_tokens.length >= 128) _tokens.remove(_tokens.keys.first);
    final token = List.generate(32, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    _tokens[token] = (peer: peer, expires: _now().add(const Duration(minutes: 30)));
    return token;
  }

  bool authorizes(String? token, String peer) {
    if (_closed) return false;
    final session = _tokens[token];
    return session != null && session.peer == peer && _now().isBefore(session.expires);
  }

  void close() {
    _closed = true;
    _tokens.clear();
    _failures.clear();
  }

  void revokePeer(String peer) => _tokens.removeWhere((_, session) => session.peer == peer);
}
