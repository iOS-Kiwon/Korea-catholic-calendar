import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_update_service.dart';

/// 앱 이름/버전/빌드번호. 설정 화면 Footer에서 사용.
final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// 스토어에 업데이트가 있는지. 서버 정책이 force/recommended면 true.
/// 웹/실패/오프라인/최신이면 false.
final appUpdateAvailableProvider = FutureProvider<bool>((ref) async {
  if (kIsWeb) return false;
  final policy = await const AppUpdateService().check();
  return policy != null;
});
