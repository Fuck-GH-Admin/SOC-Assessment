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

      final result = <String>[];
      await for (final chunk in service.generateStream(
        baseUrl: testBaseUrl,
        apiKey: testApiKey,
        model: testModel,
        prompt: testPrompt,
      )) {
        result.add(chunk);
      }

      expect(result, ['你好', '世界']);
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

      final result = <String>[];
      await for (final chunk in service.generateStream(
        baseUrl: testBaseUrl,
        apiKey: testApiKey,
        model: testModel,
        prompt: testPrompt,
      )) {
        result.add(chunk);
      }

      expect(result, ['第一段']);
      expect(result.length, 1);
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

      final result = <String>[];
      await for (final chunk in service.generateStream(
        baseUrl: testBaseUrl,
        apiKey: testApiKey,
        model: testModel,
        prompt: testPrompt,
      )) {
        result.add(chunk);
      }

      expect(result, ['内容']);
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

      final result = <String>[];
      await for (final chunk in service.generateStream(
        baseUrl: testBaseUrl,
        apiKey: testApiKey,
        model: testModel,
        prompt: testPrompt,
        cancelToken: cancelToken,
      )) {
        result.add(chunk);
      }

      expect(result, isEmpty);
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
      // SSE 可能将一条 data 分割成多行
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

      final result = <String>[];
      await for (final chunk in service.generateStream(
        baseUrl: testBaseUrl,
        apiKey: testApiKey,
        model: testModel,
        prompt: testPrompt,
      )) {
        result.add(chunk);
      }

      expect(result, ['完整']);
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
  });
}
