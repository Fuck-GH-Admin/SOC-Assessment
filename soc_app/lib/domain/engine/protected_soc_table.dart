// Linux Release-only native SOC reference lookup.
// AOT selection is controlled by --dart-define=SOC_NATIVE_TABLE=true.
// Dev/test/Windows builds remain on the original reference implementation.
import 'dart:ffi' as ffi;

typedef _NativeSocAccess = ffi.Double Function(
  ffi.Int32 treatment,
  ffi.Int32 erosion,
  ffi.Int32 depth,
);
typedef _DartSocAccess = double Function(
  int treatment,
  int erosion,
  int depth,
);

final _DartSocAccess _nativeAccess = ffi.DynamicLibrary.process()
    .lookupFunction<_NativeSocAccess, _DartSocAccess>('soc_data_access');

double protectedSocLookup(int treatment, int erosion, int depth) {
  final result = _nativeAccess(treatment, erosion, depth);
  if (!result.isFinite) {
    throw StateError('Protected SOC data verification failed');
  }
  return result;
}
