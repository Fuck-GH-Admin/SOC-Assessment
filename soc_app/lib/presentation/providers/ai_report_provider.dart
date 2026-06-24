import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ai_report_service.dart';
import '../../data/ai_report_prompt.dart';
import '../../domain/models/calculation_params.dart';
import '../../domain/models/calculation_result.dart';
import 'calculator_provider.dart';

class AiReportState {
  final String streamContent;
  final String? reasoningContent;
  final bool isGenerating;
  final String? error;

  const AiReportState({
    this.streamContent = '',
    this.reasoningContent,
    this.isGenerating = false,
    this.error,
  });

  AiReportState copyWith({
    String? streamContent,
    String? reasoningContent,
    bool? isGenerating,
    String? error,
  }) {
    return AiReportState(
      streamContent: streamContent ?? this.streamContent,
      reasoningContent: reasoningContent ?? this.reasoningContent,
      isGenerating: isGenerating ?? this.isGenerating,
      error: error,
    );
  }
}

class AiReportNotifier extends Notifier<AiReportState> {
  CancelToken? _cancelToken;
  final AiReportService _service = AiReportService();

  @override
  AiReportState build() {
    ref.onDispose(() => _cancelToken?.cancel());
    return const AiReportState();
  }

  Future<void> generateReport({
    required String baseUrl,
    required String apiKey,
    required String model,
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

    final prompt = fillPrompt(
      customPrompt ?? defaultPrompt,
      _buildPromptData(params, result),
    );

    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    state = const AiReportState(isGenerating: true);

    final buffer = StringBuffer();

    try {
      await for (final chunk in _service.generateStream(
        baseUrl: baseUrl,
        apiKey: apiKey,
        model: model,
        prompt: prompt,
        enableThinking: enableThinking,
        reasoningEffort: reasoningEffort,
        extraThinkingBody: extraThinkingBody,
        cancelToken: _cancelToken,
      )) {
        buffer.write(chunk);
        state = state.copyWith(streamContent: buffer.toString());
      }
      state = state.copyWith(isGenerating: false, streamContent: buffer.toString());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      final msg = _formatError(e);
      state = state.copyWith(isGenerating: false, error: msg);
    } catch (e) {
      state = state.copyWith(isGenerating: false, error: e.toString());
    }
  }

  void cancel() {
    _cancelToken?.cancel();
    _cancelToken = null;
    state = state.copyWith(isGenerating: false);
  }

  void reset() {
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
      CalculationParams params, CalculationResult result) {
    return {
      'fert': params.fert,
      'erosion': params.erosion,
      'bd': params.bd,
      'ph': params.ph,
      'wc': params.wc,
      'clay': params.clay,
      'tn': params.tn,
      'cropBiomass': params.cropBiomass,
      'strawCarbonRatio': params.strawCarbonRatio,
      'soc': result.soc,
      'carbonStorage': result.carbonStorage,
      'carbonDensity': result.carbonDensity,
      'netChange': result.netChange,
      'recoveryRate': result.recoveryRate,
      'lossRate': result.lossRate,
    };
  }
}

final aiReportProvider =
    NotifierProvider<AiReportNotifier, AiReportState>(
  AiReportNotifier.new,
);
