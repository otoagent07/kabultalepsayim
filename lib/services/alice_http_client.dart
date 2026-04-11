import 'dart:convert';

import 'package:alice/model/alice_http_call.dart';
import 'package:alice/model/alice_http_request.dart';
import 'package:alice/model/alice_http_response.dart';
import 'package:http/http.dart' as http;
import 'alice_service.dart';

class AliceHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  static String _fixMojibake(String input) {
    // Example: "Ä°Ålem GÃ¼ncellendi" -> "İşlem Güncellendi"
    const mojibakeMarkers = ['Ã', 'Ä', 'Å', '�'];
    final hasMarker = mojibakeMarkers.any(input.contains);
    if (!hasMarker) return input;
    try {
      return utf8.decode(latin1.encode(input));
    } catch (_) {
      return input;
    }
  }

  static String _decodeBodyBytes(
    List<int> bytes,
    Map<String, String> headers,
  ) {
    final contentType = headers['content-type'] ?? '';
    final charsetMatch = RegExp(r'charset=([^;\s]+)', caseSensitive: false)
        .firstMatch(contentType);
    final charset = charsetMatch?.group(1)?.trim().toLowerCase();

    if (charset != null) {
      final encoding = Encoding.getByName(charset);
      if (encoding != null) {
        return _fixMojibake(encoding.decode(bytes));
      }
    }

    try {
      return _fixMojibake(utf8.decode(bytes));
    } catch (_) {
      return _fixMojibake(latin1.decode(bytes, allowInvalid: true));
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final stopwatch = Stopwatch()..start();
    final uri = request.url;
    final call = AliceHttpCall(request.hashCode)
      ..method = request.method
      ..uri = uri.toString()
      ..server = uri.host
      ..endpoint = uri.path
      ..secure = uri.scheme == 'https'
      ..client = 'http';

    final aliceRequest = AliceHttpRequest()
      ..time = DateTime.now()
      ..headers = Map<String, String>.from(request.headers)
      ..queryParameters = uri.queryParameters
      ..body = request is http.Request ? _fixMojibake(request.body) : ''
      ..contentType = request.headers['content-type'] ?? '';
    call.request = aliceRequest;

    http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _inner.send(request);
    } catch (e) {
      call
        ..loading = false
        ..duration = stopwatch.elapsedMilliseconds;
      AliceService.instance.alice.addHttpCall(call);
      rethrow;
    }

    final bytes = await streamedResponse.stream.toBytes();
    stopwatch.stop();

    final aliceResponse = AliceHttpResponse()
      ..status = streamedResponse.statusCode
      ..time = DateTime.now()
      ..headers = Map<String, String>.from(streamedResponse.headers)
      ..size = bytes.length
      ..body = _decodeBodyBytes(bytes, streamedResponse.headers);

    call
      ..response = aliceResponse
      ..duration = stopwatch.elapsedMilliseconds
      ..loading = false;

    AliceService.instance.alice.addHttpCall(call);

    return http.StreamedResponse(
      Stream.value(bytes),
      streamedResponse.statusCode,
      contentLength: bytes.length,
      request: streamedResponse.request,
      headers: streamedResponse.headers,
      reasonPhrase: streamedResponse.reasonPhrase,
      isRedirect: streamedResponse.isRedirect,
      persistentConnection: streamedResponse.persistentConnection,
    );
  }
}
