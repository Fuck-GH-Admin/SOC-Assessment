import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soc_app/data/ai_config_service.dart';

final aiConfigProvider = Provider<AiConfigService>((ref) {
  return AiConfigService();
});
