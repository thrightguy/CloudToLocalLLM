import 'dart:io';

Future<void> main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '9001') ?? 9001;

  final server = await HttpServer.bind(
    InternetAddress.anyIPv4,
    port,
  );

  print('Admin Control Daemon listening on port ${server.port}');

  await for (HttpRequest request in server) {
    try {
      if (request.uri.path == '/admin/health') {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write('{"status": "OK"}');
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..headers.contentType = ContentType.json
          ..write('{"error": "Not Found"}');
      }
    } catch (e) {
      print('Error handling request: $e');
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..headers.contentType = ContentType.json
        ..write('{"error": "Internal server error"}');
    } finally {
      await request.response.close();
    }
  }
}
