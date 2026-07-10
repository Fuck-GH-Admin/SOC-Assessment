import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soc_app/domain/engine/resilience_assessment.dart';
import 'package:soc_app/domain/engine/soc_calculator.dart';
import 'package:soc_app/domain/models/calculation_params.dart';
import 'package:soc_app/domain/models/calculation_result.dart';
import 'package:soc_app/domain/models/resilience_result.dart';

import 'draft_dao_provider.dart';
import 'history_provider.dart';
import 'record_dao_provider.dart';

class CalculatorState {
  final CalculationParams params;
  final CalculationResult? result;
  final ResilienceResult? resilience;
  final List<String> errors;
  final List<String> warnings;
  final bool isCalculated;
  final bool isCalculating;
  final int? recordId;

  const CalculatorState({
    this.params = const CalculationParams(),
    this.result,
    this.resilience,
    this.errors = const [],
    this.warnings = const [],
    this.isCalculated = false,
    this.isCalculating = false,
    this.recordId,
  });

  CalculatorState copyWith({
    CalculationParams? params,
    CalculationResult? result,
    ResilienceResult? resilience,
    List<String>? errors,
    List<String>? warnings,
    bool? isCalculated,
    bool? isCalculating,
    int? recordId,
  }) {
    return CalculatorState(
      params: params ?? this.params,
      result: result ?? this.result,
      resilience: resilience ?? this.resilience,
      errors: errors ?? this.errors,
      warnings: warnings ?? this.warnings,
      isCalculated: isCalculated ?? this.isCalculated,
      isCalculating: isCalculating ?? this.isCalculating,
      recordId: recordId ?? this.recordId,
    );
  }
}

class CalculatorNotifier extends Notifier<CalculatorState> {
  Timer? _draftTimer;
  int _calculationId = 0;

  @override
  CalculatorState build() {
    ref.onDispose(() {
      _draftTimer?.cancel();
      _calculationId++;
    });
    return const CalculatorState();
  }

  void _saveDraft() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(seconds: 2), () async {
      try {
        final dao = await ref.read(draftDaoProvider.future);
        await dao.save(state.params);
      } catch (_) {
        // 草稿保存失败不应中断当前输入流程。
      }
    });
  }

  void _replaceParams(CalculationParams params, {bool saveDraft = true}) {
    // 参数一旦变化，旧 result/resilience/AI/PDF 都不能继续视为有效。
    _calculationId++;
    state = CalculatorState(params: params);
    if (saveDraft) _saveDraft();
  }

  void loadDraft(CalculationParams params) {
    _replaceParams(params, saveDraft: false);
  }

  void loadParams(CalculationParams params) {
    _replaceParams(params);
  }

  Future<void> resetParams() async {
    _draftTimer?.cancel();
    _replaceParams(const CalculationParams(), saveDraft: false);
    try {
      final dao = await ref.read(draftDaoProvider.future);
      await dao.delete();
    } catch (_) {
      // 重置参数本身已经完成，草稿清理失败不阻断界面。
    }
  }

  void updateBd(double value) =>
      _replaceParams(state.params.copyWith(bd: value));
  void updatePh(double value) =>
      _replaceParams(state.params.copyWith(ph: value));
  void updateWc(double value) =>
      _replaceParams(state.params.copyWith(wc: value));
  void updateClay(double value) =>
      _replaceParams(state.params.copyWith(clay: value));
  void updateTn(double value) =>
      _replaceParams(state.params.copyWith(tn: value));
  void updateFert(String value) =>
      _replaceParams(state.params.copyWith(fert: value));
  void updateErosion(int value) =>
      _replaceParams(state.params.copyWith(erosion: value));
  void updateDepth(int value) =>
      _replaceParams(state.params.copyWith(depth: value));
  void updateCropBiomass(double value) =>
      _replaceParams(state.params.copyWith(cropBiomass: value));
  void updateStrawCarbonRatio(double value) =>
      _replaceParams(state.params.copyWith(strawCarbonRatio: value));
  void updateLitterCarbonInput(double value) =>
      _replaceParams(state.params.copyWith(litterCarbonInput: value));

  Future<void> calculate() async {
    if (state.isCalculating) return;
    if (state.isCalculated && state.result != null && state.recordId != null) {
      state = state.copyWith(warnings: const ['参数未变化，当前结果已是最新，未重复写入历史记录。']);
      return;
    }

    final params = state.params;
    final calculationId = ++_calculationId;
    state = CalculatorState(params: params, isCalculating: true);

    final result = computeAll(params);
    if (result.success) {
      _draftTimer?.cancel();

      final currentLayers = buildProfileLayers(
        params.fert,
        params.erosion,
        params.bd,
      );
      final initialLayers = buildProfileLayers(params.fert, 0, params.bd);

      final resilienceParams = CalculationParams(
        fert: params.fert,
        erosion: params.erosion,
        depth: params.depth,
        bd: params.bd,
        ph: params.ph,
        wc: params.wc,
        clay: params.clay,
        tn: params.tn,
        cropBiomass: params.cropBiomass,
        strawCarbonRatio: params.strawCarbonRatio,
        litterCarbonInput: params.litterCarbonInput,
        soilLayers: currentLayers,
        initialLayers: initialLayers,
      );

      final resilience = assessResilience(resilienceParams);
      final resilienceResult = resilience.success ? resilience.result : null;

      final warnings = <String>[
        if (!resilience.success)
          '当前土层计算已完成，但剖面CK参考评估失败：${resilience.errors.join('；')}',
      ];
      int? recordId;
      try {
        final dao = await ref.read(recordDaoProvider.future);
        if (calculationId != _calculationId) return;
        recordId = await dao.insert(
          params: params,
          result: result.result!,
          resilience: resilienceResult,
        );
        if (calculationId != _calculationId) {
          await dao.delete(recordId);
          ref.invalidate(historyListProvider);
          return;
        }
        ref.invalidate(historyListProvider);
      } catch (_) {
        if (calculationId != _calculationId) return;
        warnings.add('计算已完成，但历史记录保存失败；本次报告不会出现在历史记录中。');
      }

      if (calculationId != _calculationId) return;
      state = CalculatorState(
        params: params,
        result: result.result,
        resilience: resilienceResult,
        errors: [],
        warnings: warnings,
        isCalculated: true,
        isCalculating: false,
        recordId: recordId,
      );
      try {
        final draftDao = await ref.read(draftDaoProvider.future);
        if (calculationId != _calculationId) return;
        await draftDao.delete();
      } catch (_) {
        if (calculationId == _calculationId && state.isCalculated) {
          state = state.copyWith(
            warnings: [...state.warnings, '计算已完成，但旧草稿未能清理。'],
          );
        }
      }
    } else {
      if (calculationId != _calculationId) return;
      state = CalculatorState(
        params: params,
        result: null,
        errors: result.errors,
        isCalculated: false,
        isCalculating: false,
      );
    }
  }
}

final calculatorProvider =
    NotifierProvider<CalculatorNotifier, CalculatorState>(
      CalculatorNotifier.new,
    );

extension ParamsCopy on CalculationParams {
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
