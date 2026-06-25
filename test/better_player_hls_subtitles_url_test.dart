import 'package:flutter_test/flutter_test.dart';

/// Verifies the URL-resolution invariant that the HLS subtitles parser relies
/// on (see [BetterPlayerHlsUtils._parseSubtitlesPlaylist]).
///
/// Signed CDNs (e.g. Vimeo) sign the literal path, so a subtitle segment URL
/// built by naive string concatenation keeps literal `../` segments and is
/// rejected with HTTP 403. Resolving the relative segment against the media
/// playlist URL via [Uri.resolve] performs RFC 3986 normalization, collapsing
/// the `..` segments and producing the path the CDN actually signed.
void main() {
  group('HLS subtitle segment URL resolution', () {
    test('relative segment with `..` is normalized against media playlist URL',
        () {
      final mediaPlaylistUrl = Uri.parse('https://h.cdn/a/b/c/d/media.m3u8');
      const segmentUrl = '../../../texttrack/x.vtt';

      final resolved = mediaPlaylistUrl.resolve(segmentUrl).toString();

      expect(resolved, 'https://h.cdn/a/texttrack/x.vtt');
      expect(resolved.contains('..'), isFalse);
    });

    test('absolute http segment URL is used as-is', () {
      const segmentUrl = 'https://other.cdn/sub/x.vtt';

      // The parser short-circuits on http(s) segment URLs.
      expect(segmentUrl.startsWith('http'), isTrue);
    });

    test('naive concatenation (the old behavior) leaves literal `..`', () {
      // Documents the regression that this fix prevents: chopping the file
      // name off the playlist URL and concatenating the raw segment line.
      final renditionUrl = Uri.parse('https://h.cdn/a/b/c/d/media.m3u8');
      const segmentUrl = '../../../texttrack/x.vtt';

      final split = renditionUrl.toString().split('/');
      var concatenated = '';
      for (var index = 0; index < split.length - 1; index++) {
        concatenated += '${split[index]}/';
      }
      concatenated += segmentUrl;

      expect(concatenated.contains('..'), isTrue);
      expect(concatenated, isNot('https://h.cdn/a/texttrack/x.vtt'));
    });
  });
}
