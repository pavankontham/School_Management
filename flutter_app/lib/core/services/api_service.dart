import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../config/app_config.dart';
import 'storage_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

/// API Service for making HTTP requests
class ApiService {
  late final Dio _dio;
  final Logger _logger = Logger();
  
  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectionTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    _setupInterceptors();
  }
  
  void _setupInterceptors() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add auth token to requests
        final token = await StorageService.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        _logger.d('REQUEST[${options.method}] => PATH: ${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        _logger.d('RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (error, handler) async {
        _logger.e('ERROR[${error.response?.statusCode}] => PATH: ${error.requestOptions.path}');
        
        // Handle 401 - Token expired
        if (error.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry the request
            final opts = error.requestOptions;
            final token = await StorageService.getAccessToken();
            opts.headers['Authorization'] = 'Bearer $token';
            
            try {
              final response = await _dio.fetch(opts);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(error);
            }
          }
        }
        
        return handler.next(error);
      },
    ));
  }
  
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await StorageService.getRefreshToken();
      if (refreshToken == null) return false;
      
      final response = await Dio().post(
        '${AppConfig.baseUrl}/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      
      if (response.statusCode == 200 && response.data['success']) {
        await StorageService.saveAccessToken(response.data['data']['accessToken']);
        await StorageService.saveRefreshToken(response.data['data']['refreshToken']);
        return true;
      }
    } catch (e) {
      _logger.e('Token refresh failed: $e');
    }
    
    // Clear tokens on refresh failure
    await StorageService.clearAll();
    return false;
  }
  
  // ============ HTTP Methods ============
  
  Future<ApiResponse> get(String path, {Map<String, dynamic>? queryParams}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParams);
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }
  
  Future<ApiResponse> post(String path, {dynamic data}) async {
    try {
      final response = await _dio.post(path, data: data);
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }
  
  Future<ApiResponse> put(String path, {dynamic data}) async {
    try {
      final response = await _dio.put(path, data: data);
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }
  
  Future<ApiResponse> delete(String path) async {
    try {
      final response = await _dio.delete(path);
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }
  
  Future<ApiResponse> uploadFile(
    String path,
    File file, {
    String fieldName = 'file',
    Map<String, dynamic>? data,
    void Function(int, int)? onProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
        ...?data,
      });
      
      final response = await _dio.post(
        path,
        data: formData,
        onSendProgress: onProgress,
      );
      
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }
  
  Future<ApiResponse> uploadMultipleFiles(
    String path,
    List<File> files, {
    String fieldName = 'files',
    Map<String, dynamic>? data,
    void Function(int, int)? onProgress,
  }) async {
    try {
      final multipartFiles = await Future.wait(
        files.map((file) => MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        )),
      );
      
      final formData = FormData.fromMap({
        fieldName: multipartFiles,
        ...?data,
      });
      
      final response = await _dio.post(
        path,
        data: formData,
        onSendProgress: onProgress,
      );
      
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }
  
  ApiResponse _handleError(DioException e) {
    String message = 'An error occurred';
    
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timeout. Please check your internet connection.';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'No internet connection. Please check your network.';
    } else if (e.response != null) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        message = data['message'];
      } else {
        message = 'Server error: ${e.response?.statusCode}';
      }
    }
    
    return ApiResponse.error(message, statusCode: e.response?.statusCode);
  }
}

/// API Response wrapper
class ApiResponse {
  final bool success;
  final dynamic data;
  final String? message;
  final int? statusCode;
  
  ApiResponse._({
    required this.success,
    this.data,
    this.message,
    this.statusCode,
  });
  
  factory ApiResponse.success(dynamic data) {
    return ApiResponse._(
      success: data['success'] ?? true,
      data: data['data'],
      message: data['message'],
    );
  }
  
  factory ApiResponse.error(String message, {int? statusCode}) {
    return ApiResponse._(
      success: false,
      message: message,
      statusCode: statusCode,
    );
  }
}

