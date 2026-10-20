/// Edit app-specific query parameters without re-encoding signed URL parameters.
class SourceLink {
  static String? parameter(String link, String name) {
    try {
      return Uri.tryParse(link)?.queryParameters[name];
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  static bool isValid(String link) {
    try {
      Uri.decodeComponent(link);
    } on FormatException {
      return false;
    } on ArgumentError {
      return false;
    }
    final uri = Uri.tryParse(link);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }

  static String configure(String link, String title, String userAgent) {
    final fragmentIndex = link.indexOf('#');
    final fragment = fragmentIndex < 0 ? '' : link.substring(fragmentIndex);
    final address = fragmentIndex < 0 ? link : link.substring(0, fragmentIndex);
    final queryIndex = address.indexOf('?');
    final base = queryIndex < 0 ? address : address.substring(0, queryIndex);
    final parts = queryIndex < 0
        ? <String>[]
        : address.substring(queryIndex + 1).split('&').where((part) {
            final name = Uri.decodeQueryComponent(part.split('=').first);
            return name != 'tl' && name != 'ua' && part.isNotEmpty;
          }).toList();
    if (title.trim().isNotEmpty) parts.add('tl=${Uri.encodeQueryComponent(title.trim())}');
    if (userAgent.trim().isNotEmpty) parts.add('ua=${Uri.encodeQueryComponent(userAgent.trim())}');
    return '$base${parts.isEmpty ? '' : '?${parts.join('&')}'}$fragment';
  }
}
