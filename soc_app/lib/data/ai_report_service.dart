import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

class AiReportResponse {
  final String content;
  final String? reasoningContent;

  const AiReportResponse({required this.content, this.reasoningContent});
}

class AiReportService {
  final Dio _dio;

  AiReportService({Dio? dio}) : _dio = dio ?? Dio();

  Stream<String> generateStream({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String prompt,
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
      enableThinking: enableThinking,
      reasoningEffort: reasoningEffort,
      extraThinkingBody: extraThinkingBody,
      cancelToken: cancelToken,
      idleTimeout: idleTimeout,
    );
  }

  Stream<String> _streamResponse({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String prompt,
    required bool enableThinking,
    String? reasoningEffort,
    Map<String, dynamic>? extraThinkingBody,
    CancelToken? cancelToken,
    Duration idleTimeout = const Duration(seconds: 60),
  }) async* {
    final body = <String, dynamic>{
      'model': model,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
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
      body['max_tokens'] = 2000;
    }

    final endpoint = baseUrl.endsWith('/')
        ? '${baseUrl}chat/completions'
        : '$baseUrl/chat/completions';

    Timer? idleTimer;
    void resetIdleTimer() {
      idleTimer?.cancel();
      idleTimer = Timer(idleTimeout, () {
        cancelToken?.cancel();
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
          final content = chunk['choices']?[0]?['delta']?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield content;
          }
        } catch (_) {}
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      rethrow;
    } finally {
      idleTimer?.cancel();
    }
  }
}
