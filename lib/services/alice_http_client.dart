import 'package:alice/model/alice_http_call.dart';
import 'package:alice/model/alice_http_request.dart';
import 'package:alice/model/alice_http_response.dart';
import 'package:http/http.dart' as http;
import 'alice_service.dart';

class AliceHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();

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
      ..body = request is http.Request ? request.body : ''
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
      ..body = String.fromCharCodes(bytes);

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
