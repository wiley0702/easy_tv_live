import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class PortableStorage {
  static Future<void> initialize() async {
    if (!Platform.isWindows) return;
    final directory = Directory(p.dirname(Platform.resolvedExecutable));
    if (!await File(p.join(directory.path, 'portable.flag')).exists()) return;
    final data = Directory(p.join(directory.path, 'user_data'));
    await data.create(recursive: true);
    final probe = File(p.join(data.path, '.write-probe-${pid}'));
    await probe.writeAsString('ok', flush: true);
    await probe.delete();
    final preferences = PortablePreferences(
      File(p.join(data.path, 'shared_preferences.json')),
    );
    await preferences
        .getAll(); // Fail visibly instead of silently replacing corrupt data.
    SharedPreferencesStorePlatform.instance = preferences;
    PathProviderPlatform.instance = _PortablePaths(data.path);
  }
}

class _PortablePaths extends PathProviderWindows {
  _PortablePaths(this.root);
  final String root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getApplicationCachePath() async {
    final cache = Directory(p.join(root, 'cache'));
    await cache.create(recursive: true);
    return cache.path;
  }
}

/// Keeps the existing preference keys/file format, including subscription caches.
class PortablePreferences extends SharedPreferencesStorePlatform {
  PortablePreferences(this.file);
  final File file;
  Future<void> _queue = Future<void>.value();

  Future<Map<String, Object>> _read() async {
    if (!await file.exists()) return {};
    final decoded = jsonDecode(await file.readAsString());
    return Map<String, Object>.from(decoded as Map);
  }

  Future<bool> _update(void Function(Map<String, Object>) change) {
    final next = _queue.then((_) async {
      final values = await _read();
      change(values);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(jsonEncode(values), flush: true);
      await temporary.rename(file.path);
      return true;
    });
    _queue = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  @override
  Future<Map<String, Object>> getAll() async {
    await _queue;
    return _read();
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) =>
      _update((values) => values[key] = value);
  @override
  Future<bool> remove(String key) => _update((values) => values.remove(key));
  @override
  Future<bool> clear() => _update(
    (values) => values.removeWhere((key, _) => key.startsWith('flutter.')),
  );
}
