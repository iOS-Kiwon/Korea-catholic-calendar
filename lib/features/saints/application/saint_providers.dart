import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/saint_source.dart';
import '../model/saint.dart';

final saintSourceProvider = Provider<SaintSource>((ref) => const SaintSource());

final saintSearchProvider = FutureProvider.autoDispose
    .family<List<Saint>, String>((ref, query) async {
      return ref.watch(saintSourceProvider).search(query);
    });
