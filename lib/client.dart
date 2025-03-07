import 'package:http/http.dart' as http;

abstract class MisfortuneClient {
  Future<bool> spin({
    required String wheelId,
    required String code,
    required double speed,
  });
}

class HttpMisfortuneClient implements MisfortuneClient {
  @override
  Future<bool> spin({
    required String wheelId,
    required String code,
    required double speed,
  }) async {
    final response = await http.post(
      Uri.https('api.bembel.party', '/wheel/$wheelId/is_locked', {
        'speed': '$speed',
      }),
      headers: {'Authorization': 'Bearer $code'},
    );

    final statusCode = response.statusCode;
    if (statusCode == 204) {
      return true;
    } else if (statusCode == 409 || statusCode == 403) {
      return false;
    } else {
      throw Exception('Error response $statusCode');
    }
  }
}
