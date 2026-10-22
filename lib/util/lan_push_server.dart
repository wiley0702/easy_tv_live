import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../tv/html_string.dart';
import 'pairing_session.dart';
import 'log_util.dart';

typedef PushHandler = Future<Map<String, dynamic>> Function(String path, Map<String, dynamic> data, InternetAddress peer);

class _PairingRequired implements Exception {}

class LanPushServer {
  LanPushServer(this.session, this.onRequest, {this.sourceTitle = '订阅源'});
  final String sourceTitle;
  final PairingSession session;
  final PushHandler onRequest;
  HttpServer? _server;
  bool _closed = false;
  Future<void> _writeQueue = Future<void>.value();
  int get port => _server!.port;
  Future<void> start(String address, {int port = 8828}) async {
    HttpServer server;
    try {
      server = await HttpServer.bind(address, port);
    } on SocketException {
      server = await HttpServer.bind(address, 0);
    }
    if (_closed) {
      await server.close(force: true);
      return;
    }
    _server = server;
    server.listen(
      (request) => unawaited(_handle(request)),
      onError: (Object error) {
        LogUtil.e('LAN listener error: $error');
      },
    );
  }

  Future<void> close() async {
    _closed = true;
    session.close();
    await _server?.close(force: true);
  }

  void _reply(HttpRequest request, int status, Object body) {
    try {
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
      request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      if (status >= 400) request.response.persistentConnection = false;
      request.response.add(utf8.encode(jsonEncode(body)));
    } catch (error) {
      LogUtil.e('LAN response failed: $error');
      /* The peer may disconnect while an asynchronous handler runs. */
    }
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final bytes = <int>[];
    final completed = Completer<Map<String, dynamic>>();
    var size = 0;
    final subscription = request.listen(
      (chunk) {
        size += chunk.length;
        if (size <= 65536) bytes.addAll(chunk);
      },
      onError: (Object error, StackTrace stack) {
        if (!completed.isCompleted) completed.completeError(error, stack);
      },
      onDone: () {
        if (completed.isCompleted) return;
        try {
          if (size > 65536) throw const HttpException('Request too large');
          final value = jsonDecode(utf8.decode(bytes));
          if (value is! Map<String, dynamic>) throw const FormatException('Expected JSON object');
          completed.complete(value);
        } catch (error, stack) {
          completed.completeError(error, stack);
        }
      },
    );
    try {
      return await completed.future.timeout(const Duration(seconds: 5));
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      if (_closed) {
        _reply(request, 503, {'message': '服务已关闭'});
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/') {
        request.response.headers.contentType = ContentType('text', 'html', charset: 'utf-8');
        request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
        request.response.add(utf8.encode(getHtmlString('', sourceTitle)));
        return;
      }
      if (request.method != 'POST') {
        _reply(request, 405, {'message': '仅支持 POST'});
        return;
      }
      final data = await _body(request);
      final peer = request.connectionInfo!.remoteAddress;
      if (request.uri.path == '/pair') {
        if (session.blocked(peer.address)) {
          _reply(request, 429, {'message': '尝试过多，请等待 30 秒'});
          return;
        }
        final token = session.pair(data['code'] is String ? data['code'] : '', peer.address);
        _reply(request, token == null ? 403 : 200, token == null ? {'message': '配对码错误或已过期'} : {'token': token, 'message': '配对成功'});
        return;
      }
      if (!session.authorizes(request.headers.value('X-EasyTV-Token'), peer.address)) {
        _reply(request, 401, {'message': '请重新输入设备上的临时配对码'});
        return;
      }
      if (!['/', '/sync', '/ip', '/exit'].contains(request.uri.path)) {
        _reply(request, 404, {'message': '接口不存在'});
        return;
      }
      final result = await _execute(request.uri.path, data, peer, request.headers.value('X-EasyTV-Token'));
      if (!_closed) _reply(request, 200, result);
    } on _PairingRequired {
      _reply(request, 401, {'message': '配对会话已失效'});
    } on FormatException {
      _reply(request, 400, {'message': '请求数据格式无效'});
    } on ArgumentError {
      _reply(request, 400, {'message': '请求参数无效'});
    } on HttpException {
      _reply(request, 413, {'message': '请求内容过大'});
    } on TimeoutException {
      _reply(request, 408, {'message': '请求超时'});
    } catch (_) {
      if (!_closed) _reply(request, 500, {'message': '处理失败，请重试'});
    } finally {
      try {
        await request.response.close();
      } catch (_) {
        /* Client disconnected. */
      }
    }
  }

  Future<Map<String, dynamic>> _execute(String path, Map<String, dynamic> data, InternetAddress peer, String? token) async {
    final before = _writeQueue;
    final finished = Completer<void>();
    _writeQueue = finished.future;
    try {
      await before;
      if (_closed || !session.authorizes(token, peer.address)) throw _PairingRequired();
      return await onRequest(path, data, peer);
    } finally {
      finished.complete();
    }
  }
}
