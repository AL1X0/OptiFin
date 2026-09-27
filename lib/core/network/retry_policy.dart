import 'api_failure.dart';

/// Politique de nouvelle tentative des providers Riverpod.
///
/// Riverpod 3 réessaie par défaut tout provider en erreur (jusqu'à 10 fois, délai
/// croissant) : une erreur définitive (401, refus de lecture, élément introuvable)
/// resterait alors masquée derrière un indicateur de chargement pendant de longues
/// secondes. On ne réessaie que les erreurs réseau transitoires, 2 fois au plus.
Duration? networkRetry(int retryCount, Object error) {
  if (retryCount >= 2) return null;
  final transient = error is UnreachableFailure || error is TimeoutFailure || error is ServerFailure;
  if (!transient) return null;
  return Duration(milliseconds: 500 * (retryCount + 1));
}
