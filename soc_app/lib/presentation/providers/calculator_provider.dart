import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soc_app/domain/engine/resilience_assessment.dart';
import 'package:soc_app/domain/engine/soc_calculator.dart';
import 'package:soc_app/domain/models/calculation_params.dart';
import 'package:soc_app/domain/models/calculation_result.dart';
import 'package:soc_app/domain/models/resilience_result.dart';
import 'package:soc_app/domain/models/soil_layer.dart';

import 'draft_dao_provider.dart';
import 'record_dao_provider.dart';

class CalculatorState {
  final CalculationParams params;
  final CalculationResult? result;
  final ResilienceResult? resilience;
  final List<String> errors;
  final bool isCalculated;

  const CalculatorState({
    this.params = const CalculationParams(),
    this.result,
    this.resilience,
    this.errors = const [],
    this.isCalculated = false,
  });

  CalculatorState copyWith({
    CalculationParams? params,
    CalculationResult? result,
    ResilienceResult? resilience,
    List<String>? errors,
    bool? isCalculated,
  }) {
    return CalculatorState(
      params: params ?? this.params,
      result: result ?? this.result,
      resilience: resilience ?? this.resilience,
      errors: errors ?? this.errors,
      isCalculated: isCalculated ?? this.isCalculated,
    );
  }
}

class CalculatorNotifier extends Notifier<CalculatorState> {
  Timer? _draftTimer;

  @override
  CalculatorState build() {
    ref.onDispose(() {
      _draftTimer?.cancel();
    });
    return const CalculatorState();
  }

  void _saveDraft() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(seconds: 2), () async {
      final dao = await ref.read(draftDaoProvider.future);
      await dao.save(state.params);
    });
  }

  void loadDraft(CalculationParams params) {
    state = state.copyWith(params: params);
  }

  void updateBd(double value) {
    state = state.copyWith(params: state.params.copyWith(bd: value));
    _saveDraft();
  }

  void updatePh(double value) {
    state = state.copyWith(params: state.params.copyWith(ph: value));
    _saveDraft();
  }

  void updateWc(double value) {
    state = state.copyWith(params: state.params.copyWith(wc: value));
    _saveDraft();
  }

  void updateClay(double value) {
    state = state.copyWith(params: state.params.copyWith(clay: value));
    _saveDraft();
  }

  void updateTn(double value) {
    state = state.copyWith(params: state.params.copyWith(tn: value));
    _saveDraft();
  }

  void updateFert(String value) {
    state = state.copyWith(params: state.params.copyWith(fert: value));
    _saveDraft();
  }

  void updateErosion(int value) {
    state = state.copyWith(params: state.params.copyWith(erosion: value));
    _saveDraft();
  }

  void updateDepth(int value) {
    state = state.copyWith(params: state.params.copyWith(depth: value));
    _saveDraft();
  }

  void updateCropBiomass(double value) {
    state = state.copyWith(
        params: state.params.copyWith(cropBiomass: value));
    _saveDraft();
  }

  void calculate() async {
    final result = computeAll(state.params);
    if (result.success) {
      _draftTimer?.cancel();

      final params = state.params;
      final soc = result.result!.soc;
      final depth = params.depth;

      final currentLayers = splitToLayers(soc, params.bd, depth);

      final initResult = computeAll(CalculationParams(
        fert: params.fert,
        erosion: 0,
        depth: params.depth,
        bd: params.bd,
        ph: params.ph,
        wc: params.wc,
        clay: params.clay,
        tn: params.tn,
      ));
      final initSoc = initResult.success ? initResult.result!.soc : soc;
      final initialLayers = splitToLayers(initSoc, params.bd, depth);

      final resilienceParams = CalculationParams(
        fert: params.fert,
        erosion: params.erosion,
        depth: params.depth,
        bd: params.bd,
        ph: params.ph,
        wc: params.wc,
        clay: params.clay,
        tn: params.tn,
        cropBiomass: params.cropBiomass > 0 ? params.cropBiomass : 10.0,
        strawCarbonRatio: params.strawCarbonRatio,
        litterCarbonInput: params.litterCarbonInput,
        soilLayers: currentLayers,
        initialLayers: initialLayers,
      );

      final resilience = assessResilience(resilienceParams);
      final resilienceResult = resilience.success ? resilience.result : null;

      state = CalculatorState(
        params: params,
        result: result.result,
        resilience: resilienceResult,
        errors: [],
        isCalculated: true,
      );
      final dao = await ref.read(recordDaoProvider.future);
      await dao.insert(
        params: params,
        result: result.result!,
        resilience: resilienceResult,
      );
    } else {
      state = CalculatorState(
        params: state.params,
        result: null,
        errors: result.errors,
        isCalculated: false,
      );
    }
  }
}

List<SoilLayer> splitToLayers(double socValue, double bd, int depthCm) {
  if (depthCm <= 20) {
    return [
      SoilLayer(
        layerId: '0-$depthCm',
        socValue: socValue,
        bd: bd,
        thickness: depthCm.toDouble(),
      ),
    ];
  }
  return [
    SoilLayer(layerId: '0-20', socValue: socValue, bd: bd, thickness: 20.0),
    SoilLayer(
      layerId: '20-$depthCm',
      socValue: socValue,
      bd: bd,
      thickness: (depthCm - 20).toDouble(),
    ),
  ];
}

final calculatorProvider =
    NotifierProvider<CalculatorNotifier, CalculatorState>(
  CalculatorNotifier.new,
);

extension _ParamsCopy on CalculationParams {
  CalculationParams copyWith({
    String? fert,
    int? erosion,
    int? depth,
    double? bd,
    double? ph,
    double? wc,
    double? clay,
    double? tn,
    double? cropBiomass,
    double? strawCarbonRatio,
    double? litterCarbonInput,
  }) {
    return CalculationParams(
      fert: fert ?? this.fert,
      erosion: erosion ?? this.erosion,
      depth: depth ?? this.depth,
      bd: bd ?? this.bd,
      ph: ph ?? this.ph,
      wc: wc ?? this.wc,
      clay: clay ?? this.clay,
      tn: tn ?? this.tn,
      cropBiomass: cropBiomass ?? this.cropBiomass,
      strawCarbonRatio: strawCarbonRatio ?? this.strawCarbonRatio,
      litterCarbonInput: litterCarbonInput ?? this.litterCarbonInput,
      soilLayers: soilLayers,
      initialLayers: initialLayers,
    );
  }
}
