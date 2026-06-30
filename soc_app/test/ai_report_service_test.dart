import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soc_app/data/ai_report_service.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late AiReportService service;

  setUp(() {
    mockDio = MockDio();
    service = AiReportService(dio: mockDio);
  });

  group('generateStream', () {
    const testBaseUrl = 'https://api.deepseek.com';
    const testApiKey = 'sk-test-key';
    const testModel = 'deepseek-v4-pro';
    const testPrompt = 'test prompt';

    Response<dynamic> _makeResponse(String rawSseData) {
      final responseBody = ResponseBody.fromString(rawSseData, 200);
      return Response<dynamic>(
        data: responseBody,
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      );
    }

    test('正常流式返回文本内容', () async {
      final response = _makeResponse(
        'data: {"choices":[{"delta":{"content":"你好"}}]}\n'
        'data: {"choices":[{"delta":{"content":"世界"}}]}\n'
        'data: [DONE]\n',
      );
      when(() => mockDio.post(
            any(),
            options: any(named: 'options'),
            data: any(named: 'data'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => response);

      final contents = <String?>[];
      final reasonings = <String?>[];
      await for (final chunk in service.generateStream(
        baseUrl: testBaseUrl,
        apiKey: testApiKey,
        model: testModel,
        prompt: testPrompt,
      )) {
        contents.add(chunk.content);
        reasonings.add(chunk.reasoningContent);
      }

      expect(contents.where((c) => c != null), ['你好', '世界']);
      expect(reasonings.every((r) => r == null), isTrue);
    });

    test('[DONE] 终止符正确停止流', () async {
      final response = _makeResponse(
        'data: {"choices":[{"delta":{"content":"第一段"}}]}\n'
        'data: [DONE]\n'
        'data: {"choices":[{"delta":{"content":"不应出现"}}]}\n',
      );
      when(() => mockDio.post(
            any(),
            options: any(named: 'options'),
            data: any(named: 'data'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => response);

      final contents = <String?>[];
      await for (final chunk in service.generateStream(
        baseUrl: testBaseUrl,
        apiKey: testApiKey,
        model: testModel,
        prompt: testPrompt,
      )) {
        contents.add(chunk.content);
      }

      expect(contents.where((c) => c != null), ['第一段']);
    });

    test('非 data: 前缀的行被忽略', () async {
      final response = _makeResponse(
        ': heartbeat\n'
        'data: {"choices":[{"delta":{"content":"内容"}}]}\n'
        'event: done\ndata: [DONE]\n',
      );
      when(() => mockDio.post(
            any(),
            options: any(named: 'options'),
            data: any(named: 'data'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => response);

      final contents = <String?>[];
      await for (final chunk in service.generateStream(
        baseUrl: testBaseUrl,
        apiKey: testApiKey,
        model: testModel,
        prompt: testPrompt,
      )) {
        contents.add(chunk.content);
      }

      expect(contents.where((c) => c != null), ['内容']);
    });

    test('DioException.cancel 被静默处理', () async {
      final cancelToken = CancelToken();
      when(() => mockDio.post(
            any(),
            options: any(named: 'options'),
            data: any(named: 'data'),
            cancelToken: any(named: 'cancelToken'),
          )).thenThrow(
        DioException(
          type: DioExceptionType.cancel,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final chunks = <AiStreamChunk>[];
      await for (final chunk in service.generateStream(
        baseUrl: testBaseUrl,
        apiKey: testApiKey,
        model: testModel,
        prompt: testPrompt,
        cancelToken: cancelToken,
      )) {
        chunks.add(chunk);
      }

      expect(chunks, isEmpty);
    });

    test('网络错误向上传播', () async {
      when(() => mockDio.post(
            any(),
            options: any(named: 'options'),
            data: any(named: 'data'),
            cancelToken: any(named: 'cancelToken'),
          )).thenThrow(
        DioException(
          type: DioExceptionType.connectionError,
          message: 'Connection refused',
          requestOptions: RequestOptions(path: ''),
        ),
      );

      expect(
        () async {
          await for (final _ in service.generateStream(
            baseUrl: testBaseUrl,
            apiKey: testApiKey,
            model: testModel,
            prompt: testPrompt,
          )) {}
        },
        throwsA(isA<DioException>()),
      );
    });

    test('partial chunk（跨行分割）正确处理', () async {
      final response = _makeResponse(
        'data: {"choices":[{"delta":{"content":"完整"}}]}\n'
        'data: [DONE]\n',
      );
      when(() => mockDio.post(
            any(),
            options: any(named: 'options'),
            data: any(named: 'data'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => response);

      final contents = <String?>[];
      await for (final chunk in service.generateStream(
        baseUrl: testBaseUrl,
        apiKey: testApiKey,
        model: testModel,
        prompt: testPrompt,
      )) {
        contents.add(chunk.content);
      }

      expect(contents.where((c) => c != null), ['完整']);
    });

    test('思考模式新增 extraThinkingBody', () async {
      final response = _makeResponse(
        'data: {"choices":[{"delta":{"content":"思考结果"}}]}\n'
        'data: [DONE]\n',
      );
      final captured = <Map<String, dynamic>>[];
      when(() => mockDio.post(
            any(),
            options: any(named: 'options'),
            data: any(named: 'data'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((inv) async {
        captured.add(inv.namedArguments[Symbol('data')] as Map<String, dynamic>);
        return response;
      });

      await for (final _ in service.generateStream(
        baseUrl: testBaseUrl,
        apiKey: testApiKey,
        model: testModel,
        prompt: testPrompt,
        enableThinking: true,
        reasoningEffort: 'high',
        extraThinkingBody: {'thinking': {'type': 'enabled'}},
      )) {}

      expect(captured, isNotEmpty);
      final body = captured.first;
      expect(body['thinking'], {'type': 'enabled'});
      expect(body['reasoning_effort'], 'high');
    });

    test('思考模式解析 reasoning_content 字段', () async {
      final response = _makeResponse(
        'data: {"choices":[{"delta":{"reasoning_content":"正在思考..."}}]}\n'
        'data: {"choices":[{"delta":{"reasoning_content":"继续推理"}}]}\n'
        'data: {"choices":[{"delta":{"content":"最终结论"}}]}\n'
        'data: [DONE]\n',
      );
      when(() => mockDio.post(
            any(),
            options: any(named: 'options'),
            data: any(named: 'data'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => response);

      final reasonings = <String?>[];
      final contents = <String?>[];
      await for (final chunk in service.generateStream(
        baseUrl: testBaseUrl,
        apiKey: testApiKey,
        model: testModel,
        prompt: testPrompt,
        enableThinking: true,
      )) {
        reasonings.add(chunk.reasoningContent);
        contents.add(chunk.content);
      }

      // 思考过程被正确提取
      expect(reasonings.where((r) => r != null), ['正在思考...', '继续推理']);
      // 正文 content 与 reasoning 分离
      expect(contents.where((c) => c != null), ['最终结论']);
    });

    test('content 与 reasoning_content 同时存在的 chunk', () async {
      final response = _makeResponse(
        'data: {"choices":[{"delta":{"content":"正文","reasoning_content":"思考"}}]}\n'
        'data: [DONE]\n',
      );
      when(() => mockDio.post(
            any(),
            options: any(named: 'options'),
            data: any(named: 'data'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => response);

      final chunks = <AiStreamChunk>[];
      await for (final chunk in service.generateStream(
        baseUrl: testBaseUrl,
        apiKey: testApiKey,
        model: testModel,
        prompt: testPrompt,
      )) {
        chunks.add(chunk);
      }

      expect(chunks.length, 1);
      expect(chunks.first.content, '正文');
      expect(chunks.first.reasoningContent, '思考');
    });
  });
}
