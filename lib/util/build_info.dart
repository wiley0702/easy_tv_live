class BuildInfo {
  static const version = '2.9.9';
  static const buildNumber = int.fromEnvironment('BUILD_NUMBER', defaultValue: 10260922);
  static const buildDate = String.fromEnvironment('BUILD_DATE');
  static const displayVersion = buildDate == '' ? version : '$version · $buildDate';

  static int compareVersions(String left, String right) {
    final a = left.replaceFirst(RegExp(r'^v'), '').split('.');
    final b = right.replaceFirst(RegExp(r'^v'), '').split('.');
    for (int i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
      final delta = (i < a.length ? int.tryParse(a[i]) ?? 0 : 0) - (i < b.length ? int.tryParse(b[i]) ?? 0 : 0);
      if (delta != 0) return delta;
    }
    return 0;
  }

  static bool isNewer(String candidate, int candidateBuild) {
    final comparison = compareVersions(candidate, version);
    return comparison > 0 || (comparison == 0 && candidateBuild > buildNumber);
  }
}
