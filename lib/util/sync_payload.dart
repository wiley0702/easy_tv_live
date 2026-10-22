import 'source_link.dart';

class SyncPayload {
  static Map<String, dynamic> validate(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    if (data.containsKey('textScaleFactor')) {
      final value = data['textScaleFactor'];
      if (value is! num || !value.isFinite || value < 0.5 || value > 3) throw const FormatException('Invalid font scale');
      result['textScaleFactor'] = value.toDouble();
    }
    if (data.containsKey('isBingBg')) {
      if (data['isBingBg'] is! bool) throw const FormatException('Invalid background setting');
      result['isBingBg'] = data['isBingBg'];
    }
    if (data.containsKey('fontFamily') || data.containsKey('fontUrl')) {
      final family = data['fontFamily'];
      final url = data['fontUrl'];
      if (family is! String || family.isEmpty || url is! String || (family != 'system' && !SourceLink.isValid(url))) {
        throw const FormatException('Invalid font');
      }
      result.addAll({'fontFamily': family, 'fontUrl': url});
      if (family != 'system') {
        final parts = Uri.parse(url).pathSegments;
        final name = parts.isEmpty ? '' : parts.last;
        if (name.isEmpty || name == '.' || name == '..' || name.contains(RegExp(r'[/\\]'))) {
          throw const FormatException('Invalid font filename');
        }
      }
    }
    if (data.containsKey('videoSource')) {
      final sources = data['videoSource'];
      if (sources is! List || sources.length > 1000) throw const FormatException('Invalid subscriptions');
      final links = <String>{};
      final clean = <Map<String, dynamic>>[];
      for (final source in sources) {
        if (source is! Map ||
            source['link'] is! String ||
            !SourceLink.isValid(source['link']) ||
            source['local'] == true ||
            !links.add(source['link']) ||
            (source['selected'] != null && source['selected'] is! bool)) {
          throw const FormatException('Invalid subscription');
        }
        final ua = SourceLink.parameter(source['link'], 'ua') ?? '';
        if (ua.contains(RegExp(r'[\r\n]'))) throw const FormatException('Invalid User-Agent');
        clean.add({
          'link': source['link'],
          'selected': source['selected'] == true,
          'local': false,
          if (source['time'] is String) 'time': source['time'],
          if (source['id'] is String && RegExp(r'^[a-f0-9]{32}$').hasMatch(source['id'])) 'id': source['id'],
        });
      }
      result['videoSource'] = clean;
    }
    if (result.isEmpty) throw const FormatException('No supported settings');
    return result;
  }
}
