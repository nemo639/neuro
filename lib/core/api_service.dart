import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
class ApiService {

  static String get baseUrl {
  // ngrok tunnel → forwards to localhost:8000
  // Update URL when ngrok restarts (free plan gives new URL)
  const url = 'https://phenological-briana-frondescent.ngrok-free.dev';
  return url;
}

  static const String apiVersion = '/api/v1';
static const _storage = FlutterSecureStorage();
  // ============== TOKEN MANAGEMENT ==============
  static String? _accessToken;
  static String? _refreshToken;

  static Future<void> _saveTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
  }

  static Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
  }

  static Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  static bool get isLoggedIn => _accessToken != null;


  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  // ============== HTTP HELPERS ==============
  static Future<Map<String, dynamic>> _handleResponse(
      http.Response response) async {
    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {'success': true, 'data': data};
    } else if (response.statusCode == 401) {
      // Try refresh token
      final refreshed = await _refreshTokens();
      if (!refreshed) {
        await clearTokens();
      }
      return {'success': false, 'error': data['detail'] ?? 'Unauthorized'};
    } else {
      return {
        'success': false,
        'error': data['detail'] ?? 'Something went wrong'
      };
    }
  }

  static Future<bool> _refreshTokens() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiVersion/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveTokens(data['access_token'], data['refresh_token']);
        return true;
      }
    } catch (e) {
      print('Token refresh failed: $e');
    }
    return false;
  }

  // ============== AUTH ENDPOINTS ==============

  /// Register new user
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    String? dateOfBirth,
    String? gender,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiVersion/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
          if (phone != null) 'phone': phone,
          if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
          if (gender != null) 'gender': gender,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Verify OTP
  static Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiVersion/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp}),
      );

      final result = await _handleResponse(response);
      if (result['success'] && result['data'] != null) {
        await _saveTokens(
          result['data']['access_token'],
          result['data']['refresh_token'],
        );
      }
      return result;
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Resend OTP
  static Future<Map<String, dynamic>> resendOtp({required String email}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiVersion/auth/resend-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Login
  static Future<Map<String, dynamic>> login({
  required String email,
  required String password,
}) async {
  try {
    print('Attempting login to: $baseUrl$apiVersion/auth/login'); // Add this
    
    final response = await http.post(
      Uri.parse('$baseUrl$apiVersion/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 10)); // Add timeout

    print('Response: ${response.statusCode}'); // Add this


      final result = await _handleResponse(response);
      if (result['success'] && result['data'] != null) {
        await _saveTokens(
          result['data']['access_token'],
          result['data']['refresh_token'],
        );
      }
      return result;
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Logout
  static Future<Map<String, dynamic>> logout() async {
    try {
      await http.post(
        Uri.parse('$baseUrl$apiVersion/auth/logout'),
        headers: _headers,
      );
      await clearTokens();
      return {'success': true, 'data': {'message': 'Logged out'}};
    } catch (e) {
      await clearTokens();
      return {'success': true, 'data': {'message': 'Logged out'}};
    }
  }

  /// Forgot Password
  static Future<Map<String, dynamic>> forgotPassword(
      {required String email}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiVersion/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Reset Password
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
            '$baseUrl$apiVersion/auth/reset-password?email=$email&otp=$otp&new_password=$newPassword'),
        headers: {'Content-Type': 'application/json'},
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  // ============== USER ENDPOINTS ==============

  /// Get current user
  static Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiVersion/users/me'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Update user profile
  static Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? dateOfBirth,
    String? gender,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (firstName != null) body['first_name'] = firstName;
      if (lastName != null) body['last_name'] = lastName;
      if (phone != null) body['phone'] = phone;
      if (dateOfBirth != null) body['date_of_birth'] = dateOfBirth;
      if (gender != null) body['gender'] = gender;

      final response = await http.patch(
        Uri.parse('$baseUrl$apiVersion/users/me'),
        headers: _headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Get user profile with stats
  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiVersion/users/profile'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Get user dashboard
  static Future<Map<String, dynamic>> getUserDashboard() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiVersion/users/dashboard'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  // ============== TEST ENDPOINTS ==============

  /// Get test dashboard
  static Future<Map<String, dynamic>> getTestDashboard() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiVersion/tests/dashboard'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Create test session
  static Future<Map<String, dynamic>> createTestSession(
      {required String category}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiVersion/tests/'),
        headers: _headers,
        body: jsonEncode({'category': category}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Get latest test results with full XAI explanations (per category)
  static Future<Map<String, dynamic>> getLatestTestResults() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiVersion/tests/latest-results'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// List test sessions
  static Future<Map<String, dynamic>> listTestSessions({
    String? category,
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (category != null) 'category': category,
        if (status != null) 'status': status,
      };

      final uri = Uri.parse('$baseUrl$apiVersion/tests/')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: _headers);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Get test session details
  static Future<Map<String, dynamic>> getTestSession(
      {required int sessionId}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiVersion/tests/$sessionId'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Start test session
  static Future<Map<String, dynamic>> startTestSession(
      {required int sessionId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiVersion/tests/$sessionId/start'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Add test item (single)
  static Future<Map<String, dynamic>> addTestItem({
    required int sessionId,
    required String itemName,
    String? itemType,
    required Map<String, dynamic> rawData,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiVersion/tests/$sessionId/items'),
        headers: _headers,
        body: jsonEncode({
          'item_name': itemName,
          if (itemType != null) 'item_type': itemType,
          'raw_data': rawData,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Add test items (batch)
  static Future<Map<String, dynamic>> addTestItemsBatch({
    required int sessionId,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiVersion/tests/$sessionId/items/batch'),
        headers: _headers,
        body: jsonEncode({'items': items}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Complete test session (triggers ML processing)
  static Future<Map<String, dynamic>> completeTestSession(
      {required int sessionId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiVersion/tests/$sessionId/complete'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Upload audio recording for a speech test item.
  /// Returns {'success': true, 'data': {'server_audio_path': '...', ...}}
  static Future<Map<String, dynamic>> uploadTestAudio({
    required int sessionId,
    required String itemName,
    required String filePath,
  }) async {
    try {
      final uri = Uri.parse(
          '$baseUrl$apiVersion/tests/$sessionId/audio?item_name=$itemName');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $_accessToken';

      // Read the file from device storage
      final file = File(filePath);
      if (!await file.exists()) {
        return {'success': false, 'error': 'Audio file not found: $filePath'};
      }

      final bytes = await file.readAsBytes();
      final fileName = filePath.split('/').last;
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: MediaType('audio', 'wav'),
      ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['detail'] ?? 'Audio upload failed'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Audio upload error: $e'};
    }
  }

  /// Cancel test session
  static Future<Map<String, dynamic>> cancelTestSession(
      {required int sessionId}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiVersion/tests/$sessionId'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  // ============== WELLNESS ENDPOINTS ==============

  /// Get wellness dashboard
  static Future<Map<String, dynamic>> getWellnessDashboard() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiVersion/wellness/dashboard'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Create wellness entry
  static Future<Map<String, dynamic>> createWellnessEntry({
    double? sleepHours,
    String? sleepQuality,
    double? screenTimeHours,
    double? gamingHours,
    int? stressLevel,
    String? mood,
    int? anxietyLevel,
    int? physicalActivityMinutes,
    String? exerciseType,
    int? waterIntakeGlasses,
    String? notes,
    String? entryDate,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (sleepHours != null) body['sleep_hours'] = sleepHours;
      if (sleepQuality != null) body['sleep_quality'] = sleepQuality;
      if (screenTimeHours != null) body['screen_time_hours'] = screenTimeHours;
      if (gamingHours != null) body['gaming_hours'] = gamingHours;
      if (stressLevel != null) body['stress_level'] = stressLevel;
      if (mood != null) body['mood'] = mood;
      if (anxietyLevel != null) body['anxiety_level'] = anxietyLevel;
      if (physicalActivityMinutes != null)
        body['physical_activity_minutes'] = physicalActivityMinutes;
      if (exerciseType != null) body['exercise_type'] = exerciseType;
      if (waterIntakeGlasses != null)
        body['water_intake_glasses'] = waterIntakeGlasses;
      if (notes != null) body['notes'] = notes;
      if (entryDate != null) body['entry_date'] = entryDate;

      final response = await http.post(
        Uri.parse('$baseUrl$apiVersion/wellness/data'),
        headers: _headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Get wellness history
  static Future<Map<String, dynamic>> getWellnessHistory({
    int days = 30,
    int limit = 100,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl$apiVersion/wellness/history?days=$days&limit=$limit'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Get today's wellness entry
  static Future<Map<String, dynamic>> getTodayWellness() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiVersion/wellness/today'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Update wellness entry
  static Future<Map<String, dynamic>> updateWellnessEntry({
    required int entryId,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl$apiVersion/wellness/$entryId'),
        headers: _headers,
        body: jsonEncode(data ?? {}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }


  /// Save wellness goals
  static Future<Map<String, dynamic>> saveWellnessGoals({
    required Map<String, double> goals,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiVersion/wellness/goals'),
        headers: _headers,
        body: jsonEncode({
          'screen_time_goal': goals['screen_time'],
          'sleep_goal': goals['sleep'],
          'gaming_goal': goals['gaming'],
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Get wellness goals
  static Future<Map<String, dynamic>> getWellnessGoals() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiVersion/wellness/goals'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }
  /// Submit wellness data (screen time, gaming, etc.) collected from device
  static Future<Map<String, dynamic>> submitWellnessData({
    required double screenTimeHours,
    double? gamingHours,
    int? stressLevel,
    int? physicalActivityMinutes,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'screen_time_hours': screenTimeHours,
      };
      if (gamingHours != null) body['gaming_hours'] = gamingHours;
      if (stressLevel != null) body['stress_level'] = stressLevel;
      if (physicalActivityMinutes != null) body['physical_activity_minutes'] = physicalActivityMinutes;
      if (notes != null) body['notes'] = notes;

      final response = await http.post(
        Uri.parse('$baseUrl$apiVersion/wellness/data'),
        headers: _headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  // ============== NOTIFICATION ENDPOINTS ==============

  /// Get user notifications/alerts
  static Future<Map<String, dynamic>> getNotifications({int limit = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiVersion/notifications?limit=$limit'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Mark notification as read
  static Future<Map<String, dynamic>> markNotificationRead(int notificationId) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl$apiVersion/notifications/$notificationId/read'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Mark all notifications as read
  static Future<Map<String, dynamic>> markAllNotificationsRead() async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl$apiVersion/notifications/read-all'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Delete a notification
  static Future<Map<String, dynamic>> deleteNotification(int notificationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiVersion/notifications/$notificationId'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  // ============== REPORT ENDPOINTS ==============

  /// List reports
  static Future<Map<String, dynamic>> listReports({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiVersion/reports/?limit=$limit&offset=$offset'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Create report
  static Future<Map<String, dynamic>> createReport({
    String? title,
    String reportType = 'comprehensive',
    List<int>? sessionIds,
    String? category,
    String? dateRangeStart,
    String? dateRangeEnd,
    bool includeWellness = false,
  }) async {
    try {
      final body = <String, dynamic>{
        'report_type': reportType,
        'include_wellness': includeWellness,
      };
      if (title != null) body['title'] = title;
      if (sessionIds != null) body['session_ids'] = sessionIds;
      if (category != null) body['category'] = category;
      if (dateRangeStart != null) body['date_range_start'] = dateRangeStart;
      if (dateRangeEnd != null) body['date_range_end'] = dateRangeEnd;

      final response = await http.post(
        Uri.parse('$baseUrl$apiVersion/reports/'),
        headers: _headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Get report details
  static Future<Map<String, dynamic>> getReport({required int reportId}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiVersion/reports/$reportId'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Get report download URL
  static String getReportDownloadUrl({required int reportId}) {
    return '$baseUrl$apiVersion/reports/$reportId/download';
  }

  /// Delete report
  static Future<Map<String, dynamic>> deleteReport(
      {required int reportId}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiVersion/reports/$reportId'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  // ============== PROFILE IMAGE ENDPOINTS ==============

  /// Upload profile image - Works on Web and Mobile
  static Future<Map<String, dynamic>> uploadProfileImage(Uint8List bytes, String fileName) async {
    try {
      final uri = Uri.parse('$baseUrl$apiVersion/users/profile-image');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $_accessToken';

      // Determine content type from extension
      final ext = fileName.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png'
          : ext == 'webp' ? 'image/webp'
          : 'image/jpeg';

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        ),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'error': data['detail'] ?? 'Upload failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Upload error: $e'};
    }
  }

  /// Remove profile image
  static Future<Map<String, dynamic>> removeProfileImage() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiVersion/users/profile-image'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  // ============== HEALTH CHECK ==============

  /// Check API health
  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Accept': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ============== FEEDBACK ENDPOINTS ==============

  /// Submit feedback
  static Future<Map<String, dynamic>> submitFeedback({
    required String category,
    required String message,
    int? rating,
    String? appVersion,
    String? deviceInfo,
  }) async {
    try {
      final body = <String, dynamic>{
        'category': category,
        'message': message,
      };
      if (rating != null) body['rating'] = rating;
      if (appVersion != null) body['app_version'] = appVersion;
      if (deviceInfo != null) body['device_info'] = deviceInfo;

      final response = await http.post(
        Uri.parse('$baseUrl$apiVersion/feedback/'),
        headers: _headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Get user's feedbacks
  static Future<Map<String, dynamic>> getMyFeedbacks({
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiVersion/feedback/my-feedbacks?page=$page&per_page=$perPage'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Delete feedback
  static Future<Map<String, dynamic>> deleteFeedback({required int feedbackId}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiVersion/feedback/$feedbackId'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

// ============================================================
// DOCTOR API SERVICE METHODS
// ============================================================
// Add these methods to your existing ApiService class in api_service.dart
// Uses: http package + baseUrl (same as your existing pattern)
// ============================================================

// ==================== DOCTOR AUTH ====================

/// Doctor login
static Future<Map<String, dynamic>> doctorLogin({
  required String email,
  required String password,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/doctors/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // Store tokens
      await _storage.write(key: 'access_token', value: data['access_token']);
      await _storage.write(key: 'refresh_token', value: data['refresh_token']);
      await _storage.write(key: 'user_type', value: 'doctor');

      return {'success': true, 'data': data};
    }

    return {'success': false, 'error': data['detail'] ?? 'Login failed'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

/// Doctor forgot password
static Future<Map<String, dynamic>> doctorForgotPassword({
  required String email,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/doctors/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'message': data['message']};
    }

    return {'success': false, 'error': data['detail'] ?? 'Request failed'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

/// Doctor reset password
static Future<Map<String, dynamic>> doctorResetPassword({
  required String email,
  required String otp,
  required String newPassword,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/doctors/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'otp': otp,
        'new_password': newPassword,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'message': 'Password reset successfully'};
    }

    return {'success': false, 'error': data['detail'] ?? 'Reset failed'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

// ==================== DOCTOR PROFILE ====================

/// Get doctor profile
static Future<Map<String, dynamic>> getDoctorProfile() async {
  try {
    final token = await _storage.read(key: 'access_token');

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/doctors/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to get profile'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

/// Update doctor profile
static Future<Map<String, dynamic>> updateDoctorProfile({
  String? firstName,
  String? lastName,
  String? phone,
  String? hospitalAffiliation,
  String? department,
  String? bio,
}) async {
  try {
    final token = await _storage.read(key: 'access_token');

    final Map<String, dynamic> body = {};
    if (firstName != null) body['first_name'] = firstName;
    if (lastName != null) body['last_name'] = lastName;
    if (phone != null) body['phone'] = phone;
    if (hospitalAffiliation != null) body['hospital_affiliation'] = hospitalAffiliation;
    if (department != null) body['department'] = department;
    if (bio != null) body['bio'] = bio;

    final response = await http.patch(
      Uri.parse('$baseUrl/api/v1/doctors/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }

    return {'success': false, 'error': data['detail'] ?? 'Update failed'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

// ==================== DOCTOR DASHBOARD ====================

/// Get doctor dashboard
static Future<Map<String, dynamic>> getDoctorDashboard() async {
  try {
    final token = await _storage.read(key: 'access_token');

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/doctors/dashboard'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to get dashboard'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

// ==================== PATIENTS ====================

/// List patients with filters
static Future<Map<String, dynamic>> getPatientsList({
  String? search,
  String? riskLevel,
  int? ageMin,
  int? ageMax,
  String sortBy = 'last_test_date',
  String sortOrder = 'desc',
  int page = 1,
  int limit = 20,
}) async {
  try {
    final token = await _storage.read(key: 'access_token');

    final queryParams = <String, String>{
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (riskLevel != null) queryParams['risk_level'] = riskLevel;
    if (ageMin != null) queryParams['age_min'] = ageMin.toString();
    if (ageMax != null) queryParams['age_max'] = ageMax.toString();

    final uri = Uri.parse('$baseUrl/api/v1/doctors/patients').replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to get patients'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

/// Get patient detail
static Future<Map<String, dynamic>> getPatientDetail(String patientId) async {
  try {
    final token = await _storage.read(key: 'access_token');

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/doctors/patients/$patientId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }

    return {'success': false, 'error': data['detail'] ?? 'Patient not found'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

// ==================== CLINICAL NOTES ====================

/// Create clinical note
static Future<Map<String, dynamic>> createClinicalNote({
  required String patientId,
  required String title,
  required String content,
  String noteType = 'general',
  String? relatedSessionId,
  String? relatedReportId,
  bool isPrivate = false,
  bool isFlagged = false,
}) async {
  try {
    final token = await _storage.read(key: 'access_token');

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/doctors/notes'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'patient_id': patientId,
        'title': title,
        'content': content,
        'note_type': noteType,
        'related_session_id': relatedSessionId,
        'related_report_id': relatedReportId,
        'is_private': isPrivate,
        'is_flagged': isFlagged,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to create note'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

/// Get clinical notes list
static Future<Map<String, dynamic>> getClinicalNotes({
  String? patientId,
  String? noteType,
  bool flaggedOnly = false,
  int page = 1,
  int limit = 20,
}) async {
  try {
    final token = await _storage.read(key: 'access_token');

    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'flagged_only': flaggedOnly.toString(),
    };

    if (patientId != null) queryParams['patient_id'] = patientId;
    if (noteType != null) queryParams['note_type'] = noteType;

    final uri = Uri.parse('$baseUrl/api/v1/doctors/notes').replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to get notes'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

/// Update clinical note
static Future<Map<String, dynamic>> updateClinicalNote({
  required String noteId,
  String? title,
  String? content,
  String? noteType,
  bool? isPrivate,
  bool? isFlagged,
}) async {
  try {
    final token = await _storage.read(key: 'access_token');

    final Map<String, dynamic> body = {};
    if (title != null) body['title'] = title;
    if (content != null) body['content'] = content;
    if (noteType != null) body['note_type'] = noteType;
    if (isPrivate != null) body['is_private'] = isPrivate;
    if (isFlagged != null) body['is_flagged'] = isFlagged;

    final response = await http.patch(
      Uri.parse('$baseUrl/api/v1/doctors/notes/$noteId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to update note'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

/// Delete clinical note
static Future<Map<String, dynamic>> deleteClinicalNote(String noteId) async {
  try {
    final token = await _storage.read(key: 'access_token');

    final response = await http.delete(
      Uri.parse('$baseUrl/api/v1/doctors/notes/$noteId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return {'success': true, 'message': 'Note deleted'};
    }

    final data = jsonDecode(response.body);
    return {'success': false, 'error': data['detail'] ?? 'Failed to delete note'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

// ==================== ALERTS ====================

/// Get doctor alerts
static Future<Map<String, dynamic>> getDoctorAlerts() async {
  try {
    final token = await _storage.read(key: 'access_token');

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/doctors/alerts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to get alerts'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

// ==================== DATASET REQUESTS ====================

/// Create dataset request
static Future<Map<String, dynamic>> createDatasetRequest({
  required String purpose,
  String? researchTitle,
  String? institution,
  List<String> dataTypes = const ['cognitive', 'motor', 'speech', 'gait', 'facial'],
  DateTime? dateRangeStart,
  DateTime? dateRangeEnd,
  int minSamples = 100,
}) async {
  try {
    final token = await _storage.read(key: 'access_token');

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/doctors/dataset-requests'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'purpose': purpose,
        'research_title': researchTitle,
        'institution': institution,
        'data_types': dataTypes,
        'date_range_start': dateRangeStart?.toIso8601String(),
        'date_range_end': dateRangeEnd?.toIso8601String(),
        'min_samples': minSamples,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to create request'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

/// Get dataset requests
static Future<Map<String, dynamic>> getDatasetRequests() async {
  try {
    final token = await _storage.read(key: 'access_token');

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/doctors/dataset-requests'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to get requests'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

// ==================== ADMIN AUTH ====================

/// Admin login
static Future<Map<String, dynamic>> adminLogin({
  required String email,
  required String password,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/admin/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      await _storage.write(key: 'access_token', value: data['access_token']);
      await _storage.write(key: 'refresh_token', value: data['refresh_token']);
      await _storage.write(key: 'user_type', value: 'admin');

      return {'success': true, 'data': data};
    }

    return {'success': false, 'error': data['detail'] ?? 'Login failed'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

// ==================== HELPERS ====================

/// Get current user type (user, doctor, admin)
static Future<String?> getUserType() async {
  return await _storage.read(key: 'user_type');
}

/// Clear all auth data (logout for any user type)
static Future<void> clearAuthData() async {
  await _storage.delete(key: 'access_token');
  await _storage.delete(key: 'refresh_token');
  await _storage.delete(key: 'user_type');
}

  // ==================== DOCTOR PROFILE API METHODS ====================
// Add these methods to your existing ApiService class

 

// ==================== ADMIN DASHBOARD ====================

/// Get admin dashboard
static Future<Map<String, dynamic>> getAdminDashboard() async {
  try {
    final token = await _storage.read(key: 'access_token');

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/admin/dashboard'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to get dashboard'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
} 
  
  static Future<Map<String, dynamic>> getAdminUsersList({
  String? search,
  bool? isVerified,
  int page = 1,
  int limit = 20,
}) async {
  try {
    final token = await _storage.read(key: 'access_token');

    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (isVerified != null) queryParams['is_verified'] = isVerified.toString();

    final uri = Uri.parse('$baseUrl/api/v1/admin/users').replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to get users'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

/// Get doctors list
static Future<Map<String, dynamic>> getAdminDoctorsList({
  String? search,
  String? status,
  int page = 1,
  int limit = 20,
}) async {
  try {
    final token = await _storage.read(key: 'access_token');

    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (status != null) queryParams['status'] = status;

    final uri = Uri.parse('$baseUrl/api/v1/admin/doctors').replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to get doctors'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

static Future<Map<String, dynamic>> verifyDoctor({
  required String doctorId,
  required bool approve,
  String? rejectionReason,
}) async {
  try {
    final token = await _storage.read(key: 'access_token');

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/admin/doctors/verify'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'doctor_id': doctorId,
        'approve': approve,
        'rejection_reason': rejectionReason,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'message': data['message']};
    }

    return {'success': false, 'error': data['detail'] ?? 'Verification failed'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

// ==================== SUPPORT TICKETS ====================

/// Get support tickets
static Future<Map<String, dynamic>> getAdminTickets({
  String? status,
  String? priority,
  int page = 1,
  int limit = 20,
}) async {
  try {
    final token = await _storage.read(key: 'access_token');

    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (status != null) queryParams['status'] = status;
    if (priority != null) queryParams['priority'] = priority;

    final uri = Uri.parse('$baseUrl/api/v1/admin/tickets').replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to get tickets'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

/// Get ticket detail
static Future<Map<String, dynamic>> getAdminTicketDetail(String ticketId) async {
  try {
    final token = await _storage.read(key: 'access_token');

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/admin/tickets/$ticketId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }

    return {'success': false, 'error': data['detail'] ?? 'Ticket not found'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

/// Assign ticket
static Future<Map<String, dynamic>> assignTicket({
  required String ticketId,
  String? adminId,
}) async {
  try {
    final token = await _storage.read(key: 'access_token');

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/admin/tickets/assign'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'ticket_id': ticketId,
        'admin_id': adminId,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'message': 'Ticket assigned'};
    }

    return {'success': false, 'error': data['detail'] ?? 'Assignment failed'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

/// Resolve ticket
static Future<Map<String, dynamic>> resolveTicket({
  required String ticketId,
  required String resolutionNotes,
}) async {
  try {
    final token = await _storage.read(key: 'access_token');

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/admin/tickets/resolve'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'ticket_id': ticketId,
        'resolution_notes': resolutionNotes,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'message': 'Ticket resolved'};
    }

    return {'success': false, 'error': data['detail'] ?? 'Resolution failed'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

/// Reply to ticket
static Future<Map<String, dynamic>> replyToTicket({
  required String ticketId,
  required String message,
}) async {
  try {
    final token = await _storage.read(key: 'access_token');

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/admin/tickets/reply'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'ticket_id': ticketId,
        'message': message,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'message': 'Reply sent'};
    }

    return {'success': false, 'error': data['detail'] ?? 'Reply failed'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

// ==================== PERMISSIONS ====================

/// Get permissions list
static Future<Map<String, dynamic>> getAdminPermissions({
  String? granteeType,
}) async {
  try {
    final token = await _storage.read(key: 'access_token');

    final queryParams = <String, String>{};
    if (granteeType != null) queryParams['grantee_type'] = granteeType;

    final uri = Uri.parse('$baseUrl/api/v1/admin/permissions').replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to get permissions'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

/// Grant permission
static Future<Map<String, dynamic>> grantPermission({
  required String granteeType,
  required String granteeId,
  required String permissionType,
  String? resourceType,
  int? expiresInDays,
}) async {
  try {
    final token = await _storage.read(key: 'access_token');

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/admin/permissions/grant'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'grantee_type': granteeType,
        'grantee_id': granteeId,
        'permission_type': permissionType,
        'resource_type': resourceType,
        'expires_in_days': expiresInDays,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'message': 'Permission granted'};
    }

    return {'success': false, 'error': data['detail'] ?? 'Grant failed'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

/// Revoke permission
static Future<Map<String, dynamic>> revokePermission({
  required String permissionId,
  required String reason,
}) async {
  try {
    final token = await _storage.read(key: 'access_token');

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/admin/permissions/revoke'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'permission_id': permissionId,
        'reason': reason,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'message': 'Permission revoked'};
    }

    return {'success': false, 'error': data['detail'] ?? 'Revoke failed'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

  // ============== NEURO CHAT ==============

  // ── Conversation Management ──

  static Future<Map<String, dynamic>> getConversations() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiVersion/chat/conversations'),
        headers: _headers,
      );
      return await _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> createConversation({String title = 'New Chat'}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiVersion/chat/conversations'),
        headers: _headers,
        body: jsonEncode({'title': title}),
      );
      return await _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> renameConversation({
    required String conversationId,
    required String title,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$apiVersion/chat/conversations/$conversationId/rename'),
        headers: _headers,
        body: jsonEncode({'title': title}),
      );
      return await _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteConversation({
    required String conversationId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiVersion/chat/conversations/$conversationId'),
        headers: _headers,
      );
      return await _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── Chat Messages ──

  static Future<Map<String, dynamic>> getChatHistory({
    required String conversationId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiVersion/chat/history?conversation_id=$conversationId'),
        headers: _headers,
      );
      return await _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    String? conversationId,
  }) async {
    try {
      final body = {
        'message': message,
        if (conversationId != null) 'conversation_id': conversationId,
      };
      final response = await http.post(
        Uri.parse('$baseUrl$apiVersion/chat/send'),
        headers: _headers,
        body: jsonEncode(body),
      );
      return await _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> clearAllChats() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiVersion/chat/clear'),
        headers: _headers,
      );
      return await _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ============== SYMPTOM TRACKER ENDPOINTS ==============

  /// Log daily symptoms
  static Future<Map<String, dynamic>> logSymptoms({
    int memoryIssues = 0,
    int confusion = 0,
    int tremors = 0,
    int balanceIssues = 0,
    int speechDifficulty = 0,
    int sleepDisturbance = 0,
    int moodChanges = 0,
    int fatigue = 0,
    String? notes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiVersion/symptoms/log'),
        headers: _headers,
        body: jsonEncode({
          'memory_issues': memoryIssues,
          'confusion': confusion,
          'tremors': tremors,
          'balance_issues': balanceIssues,
          'speech_difficulty': speechDifficulty,
          'sleep_disturbance': sleepDisturbance,
          'mood_changes': moodChanges,
          'fatigue': fatigue,
          if (notes != null) 'notes': notes,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Get today's symptoms
  static Future<Map<String, dynamic>> getTodaySymptoms() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiVersion/symptoms/today'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  /// Get symptom history
  static Future<Map<String, dynamic>> getSymptomHistory({int days = 30}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiVersion/symptoms/history?days=$days'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

}
