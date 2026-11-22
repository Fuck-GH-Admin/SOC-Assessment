import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'domain/engine/soc_calculator.dart' show lookupBaseSOC;
import 'core/theme/theme_provider.dart';
import 'presentation/pages/home/home_page.dart';

const bool _nativeTableEnabled = bool.fromEnvironment('SOC_NATIVE_TABLE');

void _assertNativeReferenceParity() {
  // Exercise all 80 release FFI calls, not merely the GUI startup.
  // A digest avoids embedding the 80 plaintext reference values back
  // into the obfuscated Dart AOT snapshot.
  const treatments = ['F', 'UNF'];
  const erosions = [0, 10, 20, 30, 40, 50, 60, 70];
  const depths = [10, 25, 35, 45, 55];
  var hash = 0x811c9dc5;
  for (final treatment in treatments) {
    for (final erosion in erosions) {
      for (final depth in depths) {
        final result = lookupBaseSOC(treatment, erosion, depth);
        if (result == null || !result.isFinite) {
          throw StateError('Native SOC reference unavailable');
        }
        final centesimal = (result * 100).round();
        hash = ((hash ^ (centesimal & 255)) * 0x01000193) & 0xffffffff;
        hash = ((hash ^ ((centesimal >> 8) & 255)) * 0x01000193) &
            0xffffffff;
      }
    }
  }
  if (hash != 0x1dce3d93) {
    throw StateError('Protected SOC dataset failed release parity check');
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (_nativeTableEnabled) {
    _assertNativeReferenceParity();
  }
  runApp(const ProviderScope(child: SocApp()));
}

class SocApp extends ConsumerWidget {
  const SocApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final seedColor = ref.watch(seedColorProvider);

    return MaterialApp(
      title: '碳盾 SOC-Shield',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(seedColor),
      darkTheme: AppTheme.darkTheme(seedColor),
      themeMode: themeMode,
      home: const HomePage(),
    );
  }
}
