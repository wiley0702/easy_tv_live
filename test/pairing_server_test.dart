import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:easy_tv_live/util/lan_push_server.dart';
import 'package:easy_tv_live/util/pairing_session.dart';
import 'package:easy_tv_live/util/sync_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('codes expire, guessing is throttled, and tokens are bound to peer and lifetime', () {
    var now = DateTime(2026, 10, 22);
    final session = PairingSession(now: () => now);
    final code = session.code;
    final wrong = code == '000000' ? '111111' : '000000';
    for (var i = 0; i < 5; i++) {
      expect(session.pair(wrong, 'a'), isNull);
    }
    expect(session.blocked('a'), isTrue);
    expect(session.pair(code, 'a'), isNull);
    now = now.add(const Duration(seconds: 31));
    final token = session.pair(code, 'a');
    expect(token, isNotNull);
    expect(session.authorizes(token, 'a'), isTrue);
    expect(session.authorizes(token, 'b'), isFalse);
    now = now.add(const Duration(minutes: 5));
    expect(session.pair(code, 'b'), isNull);
    now = now.add(const Duration(minutes: 30));
    expect(session.authorizes(token, 'a'), isFalse);
    final fresh = session.issueToken('a');
    session.close();
    expect(session.authorizes(fresh, 'a'), isFalse);
  });

  test('HTTP requires pairing, rejects malformed/oversized requests, and keeps serving', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final session = PairingSession();
      var received = 0;
      final held = Completer<void>();
      final started = Completer<void>();
      final order = <String>[];
      final server = LanPushServer(session, (path, data, peer) async {
        received++;
        if (data['hold'] == true) {
          started.complete();
          await held.future;
        }
        if (data['label'] is String) order.add(data['label']);
        return {'message': 'ok'};
      });
      await server.start('127.0.0.1', port: 0);
      final client = HttpClient()..findProxy = (_) => 'DIRECT';
      Future<({int status, Map<String, dynamic> data})> post(String path, Object body, {String? token}) async {
        final request = await client.postUrl(Uri.parse('http://127.0.0.1:${server.port}$path'));
        request.headers.contentType = ContentType.json;
        if (token != null) request.headers.set('X-EasyTV-Token', token);
        request.write(body is String ? body : jsonEncode(body));
        final response = await request.close();
        return (status: response.statusCode, data: jsonDecode(await utf8.decoder.bind(response).join()) as Map<String, dynamic>);
      }

      try {
        expect((await post('/sync', {'videoSource': []})).status, 401);
        expect(received, 0);
        final paired = await post('/pair', {'code': session.code});
        expect(paired.status, 200);
        final token = paired.data['token'] as String;
        expect((await post('/sync', '{bad json', token: token)).status, 400);
        expect((await post('/sync', 'x' * 70000, token: token)).status, 413);
        expect((await post('/sync', {'videoSource': []}, token: token)).status, 200);
        expect(received, 1);
        final first = post('/sync', {'hold': true, 'label': 'first'}, token: token);
        await started.future;
        final second = post('/sync', {'label': 'second'}, token: token);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(order, isEmpty);
        held.complete();
        expect((await first).status, 200);
        expect((await second).status, 200);
        expect(order, ['first', 'second']);
        final get = await client.getUrl(Uri.parse('http://127.0.0.1:${server.port}/'));
        final page = await utf8.decoder.bind(await get.close()).join();
        expect(page.contains('pairCode'), isTrue);
        expect(page.contains(session.code), isFalse);
        session.revokePeer('127.0.0.1');
        expect((await post('/sync', {}, token: token)).status, 401);
      } finally {
        if (!held.isCompleted) held.complete();
        client.close(force: true);
        await server.close();
      }
    }, _RealHttp());
  });

  test('occupied port falls back to an available port', () async {
    final occupied = await HttpServer.bind('127.0.0.1', 0);
    final server = LanPushServer(PairingSession(), (_, _, _) async => {});
    try {
      await server.start('127.0.0.1', port: occupied.port);
      expect(server.port, isNot(occupied.port));
    } finally {
      await occupied.close(force: true);
      await server.close();
    }
  });

  test('sync validates complete payload before applying any settings', () {
    expect(
      () => SyncPayload.validate({
        'textScaleFactor': 1.2,
        'videoSource': [
          {'link': 'file:///private', 'local': true},
        ],
      }),
      throwsFormatException,
    );
    expect(() => SyncPayload.validate({'isBingBg': 'yes'}), throwsFormatException);
    expect(() => SyncPayload.validate({'fontFamily': 'custom', 'fontUrl': 'file:///font'}), throwsFormatException);
    expect(() => SyncPayload.validate({'fontFamily': 'custom', 'fontUrl': 'https://example.com/..%2Ffont.ttf'}), throwsFormatException);
    expect(
      SyncPayload.validate({
        'textScaleFactor': 1,
        'videoSource': [
          {'link': 'https://example.com/live'},
        ],
      })['textScaleFactor'],
      1.0,
    );
  });
}

class _RealHttp extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => super.createHttpClient(context);
}
