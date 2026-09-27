import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/home_repository.dart';
import '../domain/home_data.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final session = ref.watch(sessionControllerProvider);
  if (session == null) throw StateError('Aucune session active');
  return HomeRepository(ref.watch(mediaRepositoryProvider), ref.watch(responseCacheProvider), session.account.id);
});

/// Accueil : cache instantané puis réseau. Gardé en vie tant que la session dure
/// (retour sur l'onglet sans rechargement).
final homeProvider = StreamProvider<HomeData>((ref) => ref.watch(homeRepositoryProvider).watch());
