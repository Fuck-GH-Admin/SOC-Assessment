import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

class AiReportResponse {
  final String content;
  final String? reasoningContent;

  const AiReportResponse({required this.content, this.reasoningContent});
}

/// 流式 chunk：content 为正文增量，reasoningContent 为思考过程增量。
class AiStreamChunk {
  final String? content;
  final String? reasoningContent;

  const AiStreamChunk({this.content, this.reasoningContent});
}

class AiReportService {
  final Dio _dio;

  AiReportService({Dio? dio}) : _dio = dio ?? Dio();

  Stream<AiStreamChunk> generateStream({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String prompt,
    String? systemPrompt,
    bool enableThinking = false,
    String? reasoningEffort,
    Map<String, dynamic>? extraThinkingBody,
    CancelToken? cancelToken,
    Duration idleTimeout = const Duration(seconds: 60),
  }) {
    return _streamResponse(
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      prompt: prompt,
      systemPrompt: systemPrompt,
      enableThinking: enableThinking,
      reasoningEffort: reasoningEffort,
      extraThinkingBody: extraThinkingBody,
      cancelToken: cancelToken,
      idleTimeout: idleTimeout,
    );
  }

  Stream<AiStreamChunk> _streamResponse({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String prompt,
    String? systemPrompt,
    required bool enableThinking,
    String? reasoningEffort,
    Map<String, dynamic>? extraThinkingBody,
    CancelToken? cancelToken,
    Duration idleTimeout = const Duration(seconds: 60),
  }) async* {
    final messages = <Map<String, String>>[
      {'role': 'user', 'content': prompt},
    ];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.insert(0, {'role': 'system', 'content': systemPrompt});
    }

    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'stream': true,
    };

    if (enableThinking) {
      if (extraThinkingBody != null) {
        body.addAll(extraThinkingBody);
      }
      if (reasoningEffort != null) {
        body['reasoning_effort'] = reasoningEffort;
      }
    } else {
      body['temperature'] = 0.7;
    }

    final endpoint = baseUrl.endsWith('/')
        ? '${baseUrl}chat/completions'
        : '$baseUrl/chat/completions';

    Timer? idleTimer;
    void resetIdleTimer() {
      idleTimer?.cancel();
      idleTimer = Timer(idleTimeout, () {
        // 超时取消时带上明确原因，便于上层区分"用户取消"与"超时取消"
        cancelToken?.cancel(
          TimeoutException('AI 响应空闲超时', idleTimeout),
        );
      });
    }

    try {
      final response = await _dio.post(
        endpoint,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          responseType: ResponseType.stream,
          sendTimeout: const Duration(seconds: 30),
        ),
        data: body,
        cancelToken: cancelToken,
      );

      final stream = response.data.stream as Stream<List<int>>;
      final stringStream = utf8.decoder.bind(stream);
      final lines = const LineSplitter().bind(stringStream);

      resetIdleTimer();

      await for (final line in lines) {
        resetIdleTimer();
        if (cancelToken?.isCancelled == true) break;
        if (!line.startsWith('data: ')) continue;
        if (line == 'data: [DONE]') break;
        try {
          final chunk = jsonDecode(line.substring(6))
              as Map<String, dynamic>;
          final delta = chunk['choices']?[0]?['delta']
              as Map<String, dynamic>?;
          if (delta != null) {
            final content = delta['content'] as String?;
            final reasoning = delta['reasoning_content'] as String?;
            // 任意一个字段非空即 yield；空内容也允许透传以保留心跳节奏
            if ((content != null && content.isNotEmpty) ||
                (reasoning != null && reasoning.isNotEmpty)) {
              yield AiStreamChunk(
                content: content,
                reasoningContent: reasoning,
              );
            }
          }
        } catch (_) {}
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        // 区分用户主动取消与超时取消：超时取消向上抛出明确异常
        if (e.error is TimeoutException) {
          throw TimeoutException('AI 响应空闲超时，已生成内容可能不完整');
        }
        return;
      }
      rethrow;
    } finally {
      idleTimer?.cancel();
    }
  }
}
