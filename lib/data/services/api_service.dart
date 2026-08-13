import '../network/api_client.dart';

class ApiService {
  ApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<Map<String, dynamic>> chat({
    required String userId,
    required String message,
  }) async {
    final response = await _client.post<dynamic>(
      '/api/v1/chat/send',
      data: {'user_id': userId, 'message': message},
    );
    final body = response.data;
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    throw const FormatException('聊天服务返回了无效数据');
  }
}
