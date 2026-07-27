/// Worship Music Repository
///
/// TODO: replace with real Spotify/YouTube API integration
/// Currently returns a static curated list of worship songs.
/// When integrating with real APIs, implement this interface and
/// swap the provider below.
class WorshipSong {
  final String title;
  final String artist;
  final String duration;
  final String platform; // 'spotify' | 'youtube'
  final String url;
  final String thumbnailUrl;

  const WorshipSong({
    required this.title,
    required this.artist,
    required this.duration,
    required this.platform,
    required this.url,
    this.thumbnailUrl = '',
  });
}

/// Abstract music repository - implement with real API integration
abstract class MusicRepository {
  List<WorshipSong> getWorshipSongs();
}

/// Static curated implementation - replace with real API integration
class StaticMusicRepository implements MusicRepository {
  @override
  List<WorshipSong> getWorshipSongs() => _songs;

  static const List<WorshipSong> _songs = [
    WorshipSong(
      title: 'Way Maker',
      artist: 'Sinach',
      duration: '4:32',
      platform: 'spotify',
      url: 'https://open.spotify.com/track/0BKEhH4gDgOEJRi3aBYdIA',
    ),
    WorshipSong(
      title: 'Goodness of God',
      artist: 'Bethel Music',
      duration: '5:14',
      platform: 'spotify',
      url: 'https://open.spotify.com/track/2WLTpvHHEKaWHSQb6mDlCx',
    ),
    WorshipSong(
      title: 'What a Beautiful Name',
      artist: 'Hillsong Worship',
      duration: '4:58',
      platform: 'youtube',
      url: 'https://www.youtube.com/watch?v=nQWFzMvCfLE',
    ),
    WorshipSong(
      title: 'Jireh',
      artist: 'Elevation Worship',
      duration: '5:32',
      platform: 'spotify',
      url: 'https://open.spotify.com/track/32tLpFOCFiH1MOUh5BHmFJ',
    ),
    WorshipSong(
      title: 'Graves Into Gardens',
      artist: 'Elevation Worship',
      duration: '4:38',
      platform: 'youtube',
      url: 'https://www.youtube.com/watch?v=8A8L4_Snyc8',
    ),
    WorshipSong(
      title: 'Oceans (Where Feet May Fail)',
      artist: 'Hillsong United',
      duration: '5:24',
      platform: 'spotify',
      url: 'https://open.spotify.com/track/5Mw9bXG1dLNhbjofkVS2oR',
    ),
  ];
}
