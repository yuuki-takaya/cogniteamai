import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart'
    as fb_auth; // For getting ID token
import 'package:cogniteam_app/config/app_config.dart';

class ApiService {
  final Dio _dio;

  // Private constructor
  ApiService._(this._dio);

  // Singleton instance
  static ApiService? _instance;

  static Future<ApiService> getInstance() async {
    if (_instance == null) {
      final dio = await _createDioInstance();
      _instance = ApiService._(dio);
    }
    return _instance!;
  }

  static Future<Dio> _createDioInstance() async {
    final dio = Dio();

    // Try to load from .env first, then fallback to AppConfig
    final envBaseUrl = dotenv.env['BACKEND_BASE_URL'];
    print('ApiService: BACKEND_BASE_URL from .env: $envBaseUrl');

    String baseUrl;
    if (envBaseUrl != null && envBaseUrl.isNotEmpty) {
      baseUrl = envBaseUrl;
      print('ApiService: Using URL from .env file');
    } else {
      baseUrl = AppConfig.backendBaseUrl;
      print('ApiService: Using URL from AppConfig: $baseUrl');
    }

    dio.options.baseUrl = baseUrl;
    print('ApiService: Final base URL: ${dio.options.baseUrl}');

    dio.options.connectTimeout = const Duration(seconds: 15); // 15 seconds
    dio.options.receiveTimeout = const Duration(seconds: 15); // 15 seconds
    dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Add interceptor to include Firebase ID token in Authorization header
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Get the current Firebase user
          final fb_auth.User? firebaseUser =
              fb_auth.FirebaseAuth.instance.currentUser;
          if (firebaseUser != null) {
            try {
              final String? idTokenNullable = await firebaseUser
                  .getIdToken(true); // Force refresh if needed

              if (idTokenNullable != null) {
                options.headers['Authorization'] = 'Bearer $idTokenNullable';
                print('ID Token added to request headers.');
              } else {
                print('Failed to get ID token from Firebase');
              }
            } catch (e) {
              print('Error getting ID token: $e');
              // Optionally, you could reject the request if token is crucial and missing/failed
              // For now, let the request proceed without the token if an error occurs here
            }
          } else {
            print(
                'No Firebase user currently signed in. Authorization header will not be set.');
          }
          return handler.next(options); // Proceed with the request
        },
        onResponse: (response, handler) {
          // You can process responses globally here if needed
          print(
              'Response: ${response.statusCode} ${response.requestOptions.path}');
          return handler.next(response); // Proceed with the response
        },
        onError: (DioException e, handler) {
          // You can handle errors globally here
          print('Error: ${e.response?.statusCode} ${e.requestOptions.path}');
          print('Error details: ${e.message}');
          if (e.response != null) {
            print('Error response data: ${e.response?.data}');
          }
          // You might want to map DioException to a custom AppError or similar
          return handler.next(e); // Proceed with the error
        },
      ),
    );
    return dio;
  }

  // Generic GET request
  Future<Response<T>> get<T>(String path,
      {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get<T>(path, queryParameters: queryParameters);
    } on DioException {
      // Re-throw or handle as custom app exception
      rethrow;
    }
  }

  // Generic POST request
  Future<Response<T>> post<T>(String path, {dynamic data}) async {
    try {
      return await _dio.post<T>(path, data: data);
    } on DioException {
      rethrow;
    }
  }

  // Generic PUT request
  Future<Response<T>> put<T>(String path, {dynamic data}) async {
    try {
      return await _dio.put<T>(path, data: data);
    } on DioException {
      rethrow;
    }
  }

  // Generic DELETE request
  Future<Response<T>> delete<T>(String path, {dynamic data}) async {
    try {
      return await _dio.delete<T>(path, data: data);
    } on DioException {
      rethrow;
    }
  }
}
