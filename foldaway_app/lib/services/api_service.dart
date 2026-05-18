import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip.dart';
import '../models/trip_list.dart';
import '../models/list_item.dart';
//import 'dart:convert' show utf8;
import 'package:flutter/material.dart';

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
  Future<bool> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login/'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode == 200) {
      final data =  jsonDecode(utf8.decode(response.bodyBytes));
      await saveToken(data['access']);
      return true;
    }
    return false;
  }

  Future<bool> register(String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register/'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    return response.statusCode == 201;
  }

  // Подорожі
  Future<List<Trip>> getTrips() async {
    final response = await http.get(
      Uri.parse('$baseUrl/trips/'),
      headers: await _authHeaders,
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Trip.fromJson(json)).toList();
    }
    return [];
  }

  Future<Trip?> createTrip(String title, String destination) async {
    final response = await http.post(
      Uri.parse('$baseUrl/trips/'),
      headers: await _authHeaders,
      body: jsonEncode({'title': title, 'destination': destination}),
    );
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
  // Листи
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

  Future<TripList?> createList(String tripId, String title, String icon) async {
    final response = await http.post(
      Uri.parse('$baseUrl/lists/'),
      headers: await _authHeaders,
      body: jsonEncode({'trip': tripId, 'title': title, 'icon': icon, 'position': 0}),
    );
    if (response.statusCode == 201) {
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
  // Пункти листа
  Future<List<ListItem>> getItems(String listId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/items/?list=$listId'),
      headers: await _authHeaders,
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => ListItem.fromJson(json)).toList();
    }
    return [];
  }

  Future<ListItem?> createItem(String listId, String title, String description) async {
    final response = await http.post(
      Uri.parse('$baseUrl/items/'),
      headers: await _authHeaders,
      body: jsonEncode({
        'list': listId,
        'title': title,
        'description': description,
        'position': 0,
      }),
    );
    if (response.statusCode == 201) {
      return ListItem.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    }
    return null;
  }

  Future<bool> toggleItem(String id, bool isDone) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/items/$id/'),
      headers: await _authHeaders,
      body: jsonEncode({'is_done': isDone}),
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
}