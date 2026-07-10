import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ai_report_prompt.dart';
import '../../data/ai_report_service.dart';
import '../../domain/engine/soc_calculator.dart';
import '../../domain/models/calculation_params.dart';
import '../../domain/models/calculation_result.dart';
import '../../domain/models/resilience_result.dart';
import 'calculator_provider.dart';

String buildCalculationFingerprint(
  CalculationParams params,
  CalculationResult result,
  ResilienceResult? resilience,
) {
  return jsonEncode({
    'params': params.toJson(),
    'result': result.toJson(),
    'resilience': resilience?.toJson(),
  });
}

class AiReportState {
  final String streamContent;
  final String? reasoningContent;
  final bool isGenerating;
  final String? error;
  final String? sourceFingerprint;

  const AiReportState({
    this.streamContent = '',
    this.reasoningContent,
    this.isGenerating = false,
    this.error,
    this.sourceFingerprint,
  });

  AiReportState copyWith({
    String? streamContent,
    String? reasoningContent,
    bool? isGenerating,
    String? error,
    String? sourceFingerprint,
  }) {
    return AiReportState(
      streamContent: streamContent ?? this.streamContent,
      reasoningContent: reasoningContent ?? this.reasoningContent,
      isGenerating: isGenerating ?? this.isGenerating,
      error: error,
      sourceFingerprint: sourceFingerprint ?? this.sourceFingerprint,
    );
  }
}

class AiReportNotifier extends Notifier<AiReportState> {
  CancelToken? _cancelToken;
  final AiReportService _service = AiReportService();
  int _generationId = 0;

  @override
  AiReportState build() {
    ref.onDispose(() => _cancelToken?.cancel());
    return const AiReportState();
  }

  Future<void> generateReport({
    required String baseUrl,
    required String apiKey,
    required String model,
    String? systemPrompt,
    String? customPrompt,
    bool enableThinking = false,
    String? reasoningEffort,
    Map<String, dynamic>? extraThinkingBody,
  }) async {
    final calcState = ref.read(calculatorProvider);
    final params = calcState.params;
    final result = calcState.result;
    if (result == null) {
      state = state.copyWith(error: '请先进行计算');
      return;
    }
    final resilience = calcState.resilience;
    final fingerprint = buildCalculationFingerprint(params, result, resilience);

    final prompt = fillPrompt(
      customPrompt ?? defaultPrompt,
      _buildPromptData(params, result, resilience),
    );

    _cancelToken?.cancel();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    final generationId = ++_generationId;

    state = AiReportState(isGenerating: true, sourceFingerprint: fingerprint);

    final contentBuffer = StringBuffer();
    final reasoningBuffer = StringBuffer();

    try {
      await for (final chunk in _service.generateStream(
        baseUrl: baseUrl,
        apiKey: apiKey,
        model: model,
        prompt: prompt,
        systemPrompt: systemPrompt,
        enableThinking: enableThinking,
        reasoningEffort: reasoningEffort,
        extraThinkingBody: extraThinkingBody,
        cancelToken: cancelToken,
      )) {
        if (generationId != _generationId) return;
        if (chunk.content != null && chunk.content!.isNotEmpty) {
          contentBuffer.write(chunk.content);
        }
        if (chunk.reasoningContent != null &&
            chunk.reasoningContent!.isNotEmpty) {
          reasoningBuffer.write(chunk.reasoningContent);
        }
        state = state.copyWith(
          streamContent: contentBuffer.toString(),
          reasoningContent: reasoningBuffer.toString().isEmpty
              ? null
              : reasoningBuffer.toString(),
          sourceFingerprint: fingerprint,
        );
      }
      if (generationId != _generationId) return;
      state = state.copyWith(
        isGenerating: false,
        streamContent: contentBuffer.toString(),
        reasoningContent: reasoningBuffer.toString().isEmpty
            ? null
            : reasoningBuffer.toString(),
        sourceFingerprint: fingerprint,
      );
    } on DioException catch (e) {
      if (generationId != _generationId) return;
      if (e.type == DioExceptionType.cancel) return;
      final msg = _formatError(e);
      state = state.copyWith(isGenerating: false, error: msg);
    } on TimeoutException {
      if (generationId != _generationId) return;
      state = state.copyWith(
        isGenerating: false,
        error: 'AI 响应空闲超时，已生成内容可能不完整',
      );
    } catch (e) {
      if (generationId != _generationId) return;
      state = state.copyWith(isGenerating: false, error: e.toString());
    } finally {
      if (generationId == _generationId &&
          identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
      }
    }
  }

  void cancel() {
    _generationId++;
    _cancelToken?.cancel();
    _cancelToken = null;
    state = state.copyWith(isGenerating: false);
  }

  void reset() {
    _generationId++;
    _cancelToken?.cancel();
    _cancelToken = null;
    state = const AiReportState();
  }

  String _formatError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return '请求超时，请检查网络或 API 地址';
      case DioExceptionType.connectionError:
        return '网络连接失败，请检查网络或 API 地址';
      case DioExceptionType.badResponse:
        return 'API 请求失败: ${e.response?.statusCode ?? "unknown"}';
      default:
        return e.message ?? '未知错误';
    }
  }

  Map<String, dynamic> _buildPromptData(
    CalculationParams params,
    CalculationResult result,
    ResilienceResult? resilience,
  ) {
    final strawScenarios =
        resilience?.strawScenarios
            .map(
              (s) =>
                  '${s.label}: 秸秆碳输入 ${s.strawInput.toStringAsFixed(3)} kg C/m^2，系统总碳输入 ${s.totalInput.toStringAsFixed(3)} kg C/m^2',
            )
            .join('\n') ??
        '未生成秸秆还田情景';
    return {
      'algorithmVersion': kSocAlgorithmVersion,
      'fert': params.fert,
      'erosion': params.erosion,
      'depthLabel': depthDefinitionFor(params.depth).label,
      'bd': params.bd,
      'ph': params.ph,
      'wc': params.wc,
      'clay': params.clay,
      'tn': params.tn,
      'cropBiomass': params.cropBiomass,
      'strawCarbonRatio': params.strawCarbonRatio,
      'litterCarbonInput': params.litterCarbonInput,
      'soc': result.soc,
      'carbonStorage': result.carbonStorage,
      'carbonDensity': result.carbonDensity,
      'layerPoolDifference': result.netChange,
      'layerAnnualizedDifference': result.recoveryRate,
      'lossRate': result.lossRate,
      'carbonPool020': resilience?.carbonPool020,
      'carbonPool060': resilience?.carbonPool060,
      'netChange20yr': resilience?.netChange20yr,
      'netChange100yr': resilience?.netChange100yr,
      'recoveryRateAnnual': resilience?.recoveryRateAnnual,
      'resilienceStatus': resilience?.status,
      'strawScenarios': strawScenarios,
    };
  }
}

final aiReportProvider = NotifierProvider<AiReportNotifier, AiReportState>(
  AiReportNotifier.new,
);
