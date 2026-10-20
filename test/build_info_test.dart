import 'package:easy_tv_live/util/build_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('same version only updates for a newer build', () {
    expect(BuildInfo.isNewer('2.9.9', BuildInfo.buildNumber + 1), isTrue);
    expect(BuildInfo.isNewer('2.9.9', BuildInfo.buildNumber), isFalse);
    expect(BuildInfo.isNewer('2.9.8', BuildInfo.buildNumber + 1), isFalse);
    expect(BuildInfo.isNewer('2.10.0', 0), isTrue);
    expect(BuildInfo.isNewer('3.0.0', 0), isTrue);
  });
}
