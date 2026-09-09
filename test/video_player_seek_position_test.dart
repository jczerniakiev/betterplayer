import 'dart:async';

import 'package:better_player/src/configuration/better_player_buffering_configuration.dart';
import 'package:better_player/src/video_player/video_player.dart';
import 'package:better_player/src/video_player/video_player_platform_interface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake platform that lets a test drive the position reported to
/// [VideoPlayerController] by hand.
///
/// Note: `video_player.dart` resolves [VideoPlayerPlatform.instance] once into
/// a top level `final`, so a single instance has to serve the whole test file.
class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final Map<int, StreamController<VideoEvent>> _events = {};
  int _nextTextureId = 0;

  /// Position that [getPosition] reports back to the controller.
  Duration position = Duration.zero;

  /// Duration announced with the `initialized` event of the next data source.
  Duration durationToReport = const Duration(seconds: 71);

  void reset() {
    position = Duration.zero;
    durationToReport = const Duration(seconds: 71);
  }

  @override
  Future<void> init() async {}

  @override
  Future<int?> create({
    BetterPlayerBufferingConfiguration? bufferingConfiguration,
  }) async {
    final int textureId = _nextTextureId++;
    _events[textureId] = StreamController<VideoEvent>.broadcast();
    return textureId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int? textureId) =>
      _events[textureId]!.stream;

  @override
  Future<void> setDataSource(int? textureId, DataSource dataSource) async {
    /// The real platform opens the media and reports `initialized` a moment
    /// later; `_setDataSource` awaits that event before completing.
    Timer(Duration.zero, () {
      _events[textureId]?.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          key: dataSource.uri,
          duration: durationToReport,
          size: const Size(1280, 720),
        ),
      );
    });
  }

  @override
  Future<Duration> getPosition(int? textureId) async => position;

  @override
  Future<DateTime?> getAbsolutePosition(int? textureId) async => null;

  @override
  Future<void> seekTo(int? textureId, Duration? position) async {}

  @override
  Future<void> play(int? textureId) async {}

  @override
  Future<void> pause(int? textureId) async {}

  @override
  Future<void> setLooping(int? textureId, bool looping) async {}

  @override
  Future<void> setVolume(int? textureId, double volume) async {}

  @override
  Future<void> setSpeed(int? textureId, double speed) async {}

  @override
  Future<void> setTrackParameters(
    int? textureId,
    int? width,
    int? height,
    int? bitrate,
  ) async {}

  @override
  Future<void> dispose(int? textureId) async {
    await _events.remove(textureId)?.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final _FakeVideoPlayerPlatform platform = _FakeVideoPlayerPlatform();
  VideoPlayerPlatform.instance = platform;

  /// The controller polls the platform every 300ms while playing.
  Future<void> awaitPositionPoll() =>
      Future<void>.delayed(const Duration(milliseconds: 450));

  setUp(platform.reset);

  group('VideoPlayerController seek position', () {
    test(
      'seeking to the very end of a video does not freeze the position '
      'reported for the next video played by the same controller',
      () async {
        final VideoPlayerController controller = VideoPlayerController();
        addTearDown(controller.dispose);

        // --- first video, 71s long ---
        platform.durationToReport = const Duration(seconds: 71);
        await controller.setNetworkDataSource('https://example.com/one.m3u8');
        await controller.play();

        platform.position = const Duration(seconds: 8);
        await awaitPositionPoll();
        expect(controller.value.position, const Duration(seconds: 8));

        // The user drags the scrubber all the way to the end, which pauses
        // playback. No polling timer runs while paused and the position can
        // never move *past* the target anyway, so the seek mask used to stay
        // on for good.
        await controller.pause();
        platform.position = const Duration(seconds: 71);
        await controller.seekTo(const Duration(seconds: 71));
        await awaitPositionPoll();
        expect(controller.value.position, const Duration(seconds: 71));

        // --- a playlist advances to the next video on the same controller ---
        platform.position = Duration.zero;
        await controller.setNetworkDataSource('https://example.com/two.m3u8');
        await controller.play();

        platform.position = const Duration(seconds: 3);
        await awaitPositionPoll();

        expect(
          controller.value.position,
          const Duration(seconds: 3),
          reason: 'position must follow the new video, not the stale seek '
              'target left over from the previous one',
        );
        expect(
          controller.value.duration! - controller.value.position,
          const Duration(seconds: 68),
          reason: 'the countdown rendered from value must not be stuck at zero',
        );
      },
    );

    test(
      'the seek target keeps masking the position until the player catches up',
      () async {
        final VideoPlayerController controller = VideoPlayerController();
        addTearDown(controller.dispose);

        platform.durationToReport = const Duration(seconds: 71);
        await controller.setNetworkDataSource('https://example.com/one.m3u8');
        await controller.play();

        platform.position = const Duration(seconds: 10);
        await awaitPositionPoll();
        expect(controller.value.position, const Duration(seconds: 10));

        // Seek forward while the platform still reports the old position for a
        // moment. Without the mask the UI would jump backwards.
        await controller.seekTo(const Duration(seconds: 40));
        await awaitPositionPoll();
        expect(
          controller.value.position,
          const Duration(seconds: 40),
          reason: 'the stale platform position must stay masked',
        );

        // Once the player has actually moved past the target the mask is
        // dropped and real positions come through again.
        platform.position = const Duration(seconds: 41);
        await awaitPositionPoll();
        await awaitPositionPoll();
        expect(controller.value.position, const Duration(seconds: 41));
      },
    );
  });
}
