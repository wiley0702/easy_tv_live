import 'dart:io';
import 'package:easy_tv_live/entity/play_channel_list_model.dart';
import 'package:easy_tv_live/util/playlist_selection.dart';
import 'package:easy_tv_live/util/remote_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reordering restores station by identity instead of previous index', () {
    final previous = Channel(id: 'a', title: 'A', urls: ['https://example.com/a'], serialNum: 1);
    final moved = Channel(id: 'a', title: 'A', urls: ['https://example.com/a?newToken'], serialNum: 2);
    final model = PlayChannelListModel(
      playList: [
        PlayModel(
          channel: [
            Channel(id: 'b'),
            moved,
          ],
        ),
      ],
    );
    expect(PlaylistSelection.match(previous, model), same(moved));
    expect(PlaylistSelection.match(Channel(id: 'removed', urls: ['https://example.com/gone']), model), isNull);
  });
  test('duplicate channel identifiers prefer exact playback URL', () {
    final previous = Channel(id: 'same', title: 'A', urls: ['https://example.com/right']);
    final right = Channel(id: 'same', title: 'A', urls: ['https://example.com/right']);
    final model = PlayChannelListModel(
      playList: [
        PlayModel(
          channel: [
            Channel(id: 'same', title: 'A', urls: ['https://example.com/wrong']),
            right,
          ],
        ),
      ],
    );
    expect(PlaylistSelection.match(previous, model), same(right));
  });
  test('LAN selection supports 10 and 172 networks and ignores loopback/link-local', () {
    expect(RemoteUtil.selectIPv4([InternetAddress('127.0.0.1'), InternetAddress('169.254.1.1'), InternetAddress('10.0.0.2')]), '10.0.0.2');
    expect(RemoteUtil.selectIPv4([InternetAddress('172.16.0.2')]), '172.16.0.2');
    expect(RemoteUtil.selectIPv4([InternetAddress('::1')]), isNull);
  });
}
