import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/features/player/domain/playback_plan.dart';
import 'package:optifin/features/remote/cast_stream.dart';

PlaybackPlan _plan(PlayMethod method, String url) => PlaybackPlan(
  itemId: 'i',
  mediaSourceId: 'i',
  playSessionId: 's',
  method: method,
  streamUrl: Uri.parse(url),
  audioTracks: const [],
  subtitleTracks: const [],
);

void main() {
  test('le jeton est ajouté à l’adresse, le reste est conservé', () {
    final url = castUrl(_plan(PlayMethod.directPlay, 'http://s/Videos/i/stream?static=true&tag=x'), 'jeton');
    expect(url.queryParameters, {'static': 'true', 'tag': 'x', 'api_key': 'jeton'});
    expect(url.path, '/Videos/i/stream');
  });

  test('type du flux selon le mode de lecture', () {
    expect(castContentType(_plan(PlayMethod.directPlay, 'http://s/a')), 'video/mp4');
    expect(castContentType(_plan(PlayMethod.transcode, 'http://s/a.m3u8')), 'application/x-mpegURL');
  });

  test('profil limité à ce que tout Chromecast lit', () {
    final profile = castDeviceProfile();
    final direct = (profile['DirectPlayProfiles']! as List).single as Map;
    expect(direct['VideoCodec'], 'h264');
    expect(direct['Container'], isNot(contains('mkv')));
    final transcode = (profile['TranscodingProfiles']! as List).single as Map;
    expect(transcode['Protocol'], 'hls');
    expect(transcode['AudioCodec'], 'aac');
  });
}
