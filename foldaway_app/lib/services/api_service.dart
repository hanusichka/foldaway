import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/trip.dart';
import '../models/trip_list.dart';
import '../models/list_item.dart';

class AuthResult {
  final bool success;
  final String message;

  const AuthResult({
    required this.success,
    required this.message,
  });
}


class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  Future<Map<String, String>> get _authHeaders async {
    final token = await getToken();

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Авторизація
  Future<AuthResult> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login/'),
        headers: _headers,
        body: jsonEncode({
          'username': username.trim(),
          'password': password,
        }),
      );

      final body = utf8.decode(response.bodyBytes);
      final data = body.isNotEmpty ? jsonDecode(body) : {};

      if (response.statusCode == 200) {
        await saveToken(data['access']);

        return const AuthResult(
          success: true,
          message: 'Вхід виконано успішно.',
        );
      }

      return AuthResult(
        success: false,
        message: _extractErrorMessage(data, 'Невірне імʼя користувача або пароль.'),
      );
    } catch (e) {
      return const AuthResult(
        success: false,
        message: 'Не вдалося підключитися до сервера.',
      );
    }
  }

  Future<AuthResult> register(
    String username,
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register/'),
        headers: _headers,
        body: jsonEncode({
          'username': username.trim(),
          'email': email.trim(),
          'password': password,
        }),
      );

      final body = utf8.decode(response.bodyBytes);
      final data = body.isNotEmpty ? jsonDecode(body) : {};

      if (response.statusCode == 201) {
        return AuthResult(
          success: true,
          message: data['message'] ??
              'Реєстрація успішна. Перевірте пошту для підтвердження email.',
        );
      }

      return AuthResult(
        success: false,
        message: _extractErrorMessage(data, 'Помилка реєстрації.'),
      );
    } catch (e) {
      return const AuthResult(
        success: false,
        message: 'Не вдалося підключитися до сервера.',
      );
    }
  }

  Future<AuthResult> resendVerificationEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/resend-verification/'),
        headers: _headers,
        body: jsonEncode({
          'email': email.trim(),
        }),
      );

      final body = utf8.decode(response.bodyBytes);
      final data = body.isNotEmpty ? jsonDecode(body) : {};

      if (response.statusCode == 200) {
        return AuthResult(
          success: true,
          message: data['message'] ?? 'Лист підтвердження надіслано повторно.',
        );
      }

      return AuthResult(
        success: false,
        message: _extractErrorMessage(data, 'Не вдалося надіслати лист повторно.'),
      );
    } catch (e) {
      return const AuthResult(
        success: false,
        message: 'Не вдалося підключитися до сервера.',
      );
    }
  }

  String _extractErrorMessage(dynamic data, String fallback) {
    if (data is Map<String, dynamic>) {
      if (data['message'] != null) {
        return data['message'].toString();
      }

      if (data['error'] != null) {
        return data['error'].toString();
      }

      if (data['detail'] != null) {
        return data['detail'].toString();
      }

      if (data['non_field_errors'] is List && data['non_field_errors'].isNotEmpty) {
        return data['non_field_errors'].first.toString();
      }

      for (final value in data.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }

        if (value is String) {
          return value;
        }
      }
    }

    return fallback;
  }

  Future<AuthResult> requestPasswordReset(String email) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/password-reset/'),
      headers: _headers,
      body: jsonEncode({
        'email': email.trim(),
      }),
    );

    final body = utf8.decode(response.bodyBytes);
    final data = body.isNotEmpty ? jsonDecode(body) : {};

    if (response.statusCode == 200) {
      return AuthResult(
        success: true,
        message: data['message'] ??
            'Якщо акаунт із таким email існує, ми надіслали лист для відновлення пароля.',
      );
    }

    return AuthResult(
      success: false,
      message: _extractErrorMessage(data, 'Не вдалося надіслати лист.'),
    );
  } catch (e) {
    return const AuthResult(
      success: false,
      message: 'Не вдалося підключитися до сервера.',
    );
  }
}

Future<AuthResult> confirmPasswordReset({
  required String uid,
  required String token,
  required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/password-reset-confirm/'),
        headers: _headers,
        body: jsonEncode({
          'uid': uid,
          'token': token,
          'new_password': newPassword,
        }),
      );

      final body = utf8.decode(response.bodyBytes);
      final data = body.isNotEmpty ? jsonDecode(body) : {};

      if (response.statusCode == 200) {
        return AuthResult(
          success: true,
          message: data['message'] ?? 'Пароль успішно змінено.',
        );
      }

      return AuthResult(
        success: false,
        message: _extractErrorMessage(data, 'Не вдалося змінити пароль.'),
      );
    } catch (e) {
      return const AuthResult(
        success: false,
        message: 'Не вдалося підключитися до сервера.',
      );
    }
  }



  // Подорожі
  Future<List<Trip>> getTrips() async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/trips/'),
          headers: await _authHeaders,
        )
        .timeout(const Duration(seconds: 10));

    debugPrint('GET TRIPS STATUS: ${response.statusCode}');
    debugPrint('GET TRIPS BODY: ${utf8.decode(response.bodyBytes)}');

    if (response.statusCode == 200) {
      final List data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Trip.fromJson(json)).toList();
    }

    throw Exception(
      'Failed to load trips: ${response.statusCode} ${utf8.decode(response.bodyBytes)}',
    );
  }

  Future<Trip?> createTrip(
    String title,
    String destination,
    String? coverImageUrl,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/trips/'),
      headers: await _authHeaders,
      body: jsonEncode({
        'title': title,
        'destination': destination,
        'cover_image_url': coverImageUrl,
      }),
    );

    debugPrint('CREATE TRIP STATUS: ${response.statusCode}');
    debugPrint('CREATE TRIP BODY: ${utf8.decode(response.bodyBytes)}');

    if (response.statusCode == 201) {
      return Trip.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    }

    return null;
  }

  Future<bool> deleteTrip(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/trips/$id/'),
      headers: await _authHeaders,
    );

    return response.statusCode == 204;
  }

  Future<Trip?> updateTrip(
      String tripId,
      String title,
      String destination,
      String? coverImageUrl,
    ) async {
      final response = await http.patch(
        Uri.parse('$baseUrl/trips/$tripId/'),
        headers: await _authHeaders,
        body: jsonEncode({
          'title': title,
          'destination': destination,
          'cover_image_url': coverImageUrl,
        }),
      );

      debugPrint('UPDATE TRIP STATUS: ${response.statusCode}');
      debugPrint('UPDATE TRIP BODY: ${utf8.decode(response.bodyBytes)}');

      if (response.statusCode == 200) {
        return Trip.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      }

      return null;
    }

  // Списки
  Future<List<TripList>> getLists(String tripId) async {
    try {
      final token = await getToken();

      debugPrint('GET LISTS URL: $baseUrl/lists/?trip=$tripId');
      debugPrint('TOKEN EXISTS: ${token != null}');

      final response = await http
          .get(
            Uri.parse('$baseUrl/lists/?trip=$tripId'),
            headers: await _authHeaders,
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('GET LISTS STATUS: ${response.statusCode}');
      debugPrint('GET LISTS BODY: ${utf8.decode(response.bodyBytes)}');

      if (response.statusCode == 200) {
        final List data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => TripList.fromJson(json)).toList();
      }

      throw Exception(
        'Failed to load lists: ${response.statusCode} ${utf8.decode(response.bodyBytes)}',
      );
    } catch (e) {
      debugPrint('GET LISTS ERROR: $e');
      rethrow;
    }
  }

  Future<TripList?> createList(
    String tripId,
    String title,
    String icon,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/lists/'),
      headers: await _authHeaders,
      body: jsonEncode({
        'trip': tripId,
        'title': title,
        'icon': icon,
        'position': 0,
      }),
    );

    debugPrint('CREATE LIST STATUS: ${response.statusCode}');
    debugPrint('CREATE LIST BODY: ${utf8.decode(response.bodyBytes)}');

    if (response.statusCode == 201) {
      return TripList.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    }

    return null;
  }

  Future<TripList?> updateList(
    String listId,
    String title,
    String icon,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/lists/$listId/'),
      headers: await _authHeaders,
      body: jsonEncode({
        'title': title,
        'icon': icon,
      }),
    );

    debugPrint('UPDATE LIST STATUS: ${response.statusCode}');
    debugPrint('UPDATE LIST BODY: ${utf8.decode(response.bodyBytes)}');

    if (response.statusCode == 200) {
      return TripList.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    }

    return null;
  }

  Future<bool> deleteList(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/lists/$id/'),
      headers: await _authHeaders,
    );

    return response.statusCode == 204;
  }

  // Пункти списку
  Future<List<ListItem>> getItems(String listId) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/items/?list=$listId'),
          headers: await _authHeaders,
        )
        .timeout(const Duration(seconds: 10));

    debugPrint('GET ITEMS STATUS: ${response.statusCode}');
    debugPrint('GET ITEMS BODY: ${utf8.decode(response.bodyBytes)}');

    if (response.statusCode == 200) {
      final List data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => ListItem.fromJson(json)).toList();
    }

    throw Exception(
      'Failed to load items: ${response.statusCode} ${utf8.decode(response.bodyBytes)}',
    );
  }

  Future<List<ListItem>> getItemsByTrip(String tripId) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/items/?trip=$tripId'),
          headers: await _authHeaders,
        )
        .timeout(const Duration(seconds: 10));

    debugPrint('GET ITEMS BY TRIP STATUS: ${response.statusCode}');
    debugPrint('GET ITEMS BY TRIP BODY: ${utf8.decode(response.bodyBytes)}');

    if (response.statusCode == 200) {
      final List data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => ListItem.fromJson(json)).toList();
    }

    throw Exception(
      'Failed to load trip items: ${response.statusCode} ${utf8.decode(response.bodyBytes)}',
    );
  }

  Future<ListItem?> createItem(
    String listId,
    String title,
    String description,
    String externalLink,
    double? latitude,
    double? longitude,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/items/'),
      headers: await _authHeaders,
      body: jsonEncode({
        'list': listId,
        'title': title,
        'description': description,
        'external_link': externalLink,
        'position': 0,
        'latitude': latitude,
        'longitude': longitude,
      }),
    );

    debugPrint('CREATE ITEM STATUS: ${response.statusCode}');
    debugPrint('CREATE ITEM BODY: ${utf8.decode(response.bodyBytes)}');

    if (response.statusCode == 201) {
      return ListItem.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    }

    return null;
  }
  Future<ListItem?> updateItem(
    String itemId,
    String title,
    String description,
    String externalLink,
    double? latitude,
    double? longitude,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/items/$itemId/'),
      headers: await _authHeaders,
      body: jsonEncode({
        'title': title,
        'description': description,
        'external_link': externalLink,
        'latitude': latitude,
        'longitude': longitude,
      }),
    );

    debugPrint('UPDATE ITEM STATUS: ${response.statusCode}');
    debugPrint('UPDATE ITEM BODY: ${utf8.decode(response.bodyBytes)}');

    if (response.statusCode == 200) {
      return ListItem.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    }

    return null;
  }

  Future<bool> toggleItem(String id, bool isDone) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/items/$id/'),
      headers: await _authHeaders,
      body: jsonEncode({
        'is_done': isDone,
      }),
    );

    return response.statusCode == 200;
  }

  Future<bool> deleteItem(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/items/$id/'),
      headers: await _authHeaders,
    );

    return response.statusCode == 204;
  }

  Future<List<Map<String, dynamic>>> getPlaceRecommendations(
  String listId,
) async {
  final response = await http.post(
    Uri.parse('$baseUrl/places/suggestions/'),
    headers: await _authHeaders,
    body: jsonEncode({
      'list_id': listId,
    }),
  );

  debugPrint('PLACE RECOMMENDATIONS STATUS: ${response.statusCode}');
  debugPrint('PLACE RECOMMENDATIONS BODY: ${utf8.decode(response.bodyBytes)}');

  if (response.statusCode == 200) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final List items = data['items'] ?? [];

    return items.map((item) {
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  throw Exception(
    'Failed to get place recommendations: '
    '${response.statusCode} ${utf8.decode(response.bodyBytes)}',
  );
}
Future<AuthResult> shareTrip({
  required String tripId,
  required String email,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/trips/$tripId/share/'),
      headers: await _authHeaders,
      body: jsonEncode({
        'email': email.trim(),
      }),
    );

    final body = utf8.decode(response.bodyBytes);
    final data = body.isNotEmpty ? jsonDecode(body) : {};

    if (response.statusCode == 200) {
      return AuthResult(
        success: true,
        message: data['message'] ?? 'Доступ надано.',
      );
    }

    return AuthResult(
      success: false,
      message: _extractErrorMessage(data, 'Не вдалося надати доступ.'),
    );
  } catch (e) {
    return const AuthResult(
      success: false,
      message: 'Не вдалося підключитися до сервера.',
    );
  }
}

Future<AuthResult> unshareTrip({
  required String tripId,
  required String email,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/trips/$tripId/unshare/'),
      headers: await _authHeaders,
      body: jsonEncode({
        'email': email.trim(),
      }),
    );

    final body = utf8.decode(response.bodyBytes);
    final data = body.isNotEmpty ? jsonDecode(body) : {};

    if (response.statusCode == 200) {
      return AuthResult(
        success: true,
        message: data['message'] ?? 'Доступ забрано.',
      );
    }

    return AuthResult(
      success: false,
      message: _extractErrorMessage(data, 'Не вдалося забрати доступ.'),
    );
  } catch (e) {
    return const AuthResult(
      success: false,
      message: 'Не вдалося підключитися до сервера.',
    );
  }
}

}

