import 'dart:convert';
import 'dart:math';

import 'package:leadrole/shared/constants.dart';

const String kDefaultBaseUrl = AppConfig.apiBase;

class ApiClient {
  final String baseUrl;
  const ApiClient({this.baseUrl = kDefaultBaseUrl});

  Uri uri(String path, [Map<String, dynamic>? query]) {
    final norm = path.startsWith('/') ? path : '/$path';
    return Uri.parse(baseUrl).replace(path: norm, queryParameters: query);
  }

  String makeIdempotencyKey() {
    final rand = Random();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
