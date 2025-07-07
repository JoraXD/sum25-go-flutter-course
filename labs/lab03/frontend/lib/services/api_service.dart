import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8080';
  static const Duration timeout = Duration(seconds: 30);
  late http.Client _client;

  ApiService({http.Client? client}) {
    _client = client ?? http.Client();
  }

  void dispose() {
    _client.close();
  }

  Map<String, String> _getHeaders() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  T _handleResponse<T>(http.Response response, T Function(dynamic) fromJson) {
    final code = response.statusCode;
    if (code >= 200 && code < 300) {
      final Map<String, dynamic> jsonMap = jsonDecode(response.body);
      if (jsonMap['success'] == false) {
        throw ApiException(jsonMap['error'] ?? 'Unknown error');
      }
      final data = jsonMap['data'];
      try {
        return fromJson(data);
      } catch (e) {
        throw ApiException('Data parsing error: $e');
      }
    } else if (code >= 400 && code < 500) {
      throw ApiException('Client error: ${response.body}');
    } else if (code >= 500 && code < 600) {
      throw ServerException('Server error: ${response.body}');
    } else {
      throw ApiException('Unexpected HTTP status: $code');
    }
  }

  // Get all messages
  Future<List<Message>> getMessages() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/messages'), headers: _getHeaders())
          .timeout(timeout);
      return _handleResponse<List<Message>>(response, (data) {
        if (data is List) {
          return data
              .map((e) => Message.fromJson(e as Map<String, dynamic>))
              .toList();
        } else {
          throw ApiException('Invalid data format');
        }
      });
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    } on Exception catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  // Create a new message
  Future<Message> createMessage(CreateMessageRequest request) async {
    final validationError = request.validate();
    if (validationError != null) {
      throw ValidationException(validationError);
    }
    try {
      final response = await _client
          .post(Uri.parse('$baseUrl/api/messages'),
              headers: _getHeaders(), body: jsonEncode(request.toJson()))
          .timeout(timeout);
      return _handleResponse<Message>(response, (data) {
        if (data is Map<String, dynamic>) {
          return Message.fromJson(data);
        } else {
          throw ApiException('Invalid data format');
        }
      });
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    } on Exception catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  // Update an existing message
  Future<Message> updateMessage(int id, UpdateMessageRequest request) async {
    final validationError = request.validate();
    if (validationError != null) {
      throw ValidationException(validationError);
    }
    try {
      final response = await _client
          .put(Uri.parse('$baseUrl/api/messages/$id'),
              headers: _getHeaders(), body: jsonEncode(request.toJson()))
          .timeout(timeout);
      return _handleResponse<Message>(response, (data) {
        if (data is Map<String, dynamic>) {
          return Message.fromJson(data);
        } else {
          throw ApiException('Invalid data format');
        }
      });
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    } on Exception catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  // Delete a message
  Future<void> deleteMessage(int id) async {
    try {
      final response = await _client
          .delete(Uri.parse('$baseUrl/api/messages/$id'),
              headers: _getHeaders())
          .timeout(timeout);
      if (response.statusCode != 204) {
        if (response.statusCode >= 400 && response.statusCode < 500) {
          throw ApiException('Client error: ${response.body}');
        } else if (response.statusCode >= 500) {
          throw ServerException('Server error: ${response.body}');
        } else {
          throw ApiException(
              'Unexpected HTTP status: ${response.statusCode}');
        }
      }
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    } on Exception catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  // Get HTTP status information
  Future<HTTPStatusResponse> getHTTPStatus(int statusCode) async {
    if (statusCode < 100 || statusCode > 599) {
      throw ValidationException('Invalid status code');
    }
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/status/$statusCode'),
              headers: _getHeaders())
          .timeout(timeout);
      return _handleResponse<HTTPStatusResponse>(response, (data) {
        if (data is Map<String, dynamic>) {
          return HTTPStatusResponse.fromJson(data);
        } else {
          throw ApiException('Invalid data format');
        }
      });
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    } on Exception catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  // Health check
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/health'), headers: _getHeaders())
          .timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException(
            'Health check failed: ${response.statusCode} ${response.body}');
      }
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    } on Exception catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(e.toString());
    }
  }
}

// Custom exceptions
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => 'ApiException: $message';
}

class NetworkException extends ApiException {
  NetworkException(String message) : super(message);
}

class ServerException extends ApiException {
  ServerException(String message) : super(message);
}

class ValidationException extends ApiException {
  ValidationException(String message) : super(message);
}