import '../entity/play_channel_list_model.dart';

/// Restore a station by identity, never by its former position in a refreshed list.
class PlaylistSelection {
  static Channel? match(Channel? previous, PlayChannelListModel playlist) {
    if (previous == null) return null;
    final channels = playlist.playList?.expand((group) => group.channel ?? <Channel>[]).toList() ?? <Channel>[];
    Channel? find(bool Function(Channel) matches) {
      for (final channel in channels) {
        if (matches(channel)) return channel;
      }
      return null;
    }

    if (previous.id?.isNotEmpty == true) {
      final sameId = channels.where((channel) => channel.id == previous.id).toList();
      if (sameId.length == 1) return sameId.single;
      final oldUrls = previous.urls?.toSet() ?? <String>{};
      final sameAddress = sameId.where((channel) => channel.urls?.any(oldUrls.contains) == true).toList();
      if (sameAddress.length == 1) return sameAddress.single;
      final sameName = sameId.where((channel) => channel.title == previous.title).toList();
      if (sameName.length == 1) return sameName.single;
    }
    final urls = previous.urls?.toSet() ?? <String>{};
    return find((channel) => channel.urls?.any(urls.contains) == true);
  }
}
