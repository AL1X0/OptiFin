import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/core/network/api_failure.dart';
import 'package:optifin/core/network/retry_policy.dart';
import 'package:optifin/features/player/data/playback_repository.dart';

void main() {
  test('réessaie seulement les erreurs réseau transitoires, 2 fois max', () {
    expect(networkRetry(0, const UnreachableFailure()), const Duration(milliseconds: 500));
    expect(networkRetry(1, const TimeoutFailure()), const Duration(seconds: 1));
    expect(networkRetry(2, const ServerFailure(502)), isNull);
    expect(networkRetry(0, const UnauthorizedFailure()), isNull);
    expect(networkRetry(0, const PlaybackDeniedFailure('NotAllowed')), isNull);
    expect(networkRetry(0, StateError('bug')), isNull);
  });
}
