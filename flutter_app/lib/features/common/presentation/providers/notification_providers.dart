import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/api_service.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.read(apiServiceProvider));
});

class NotificationRepository {
  final ApiService _apiService;

  NotificationRepository(this._apiService);

  Future<List<NotificationModel>> getNotifications(
      {String type = 'received'}) async {
    final response =
        await _apiService.get('/notifications', queryParams: {'type': type});
    if (response.success && response.data != null) {
      final notifications = response.data['notifications'] as List;
      return notifications.map((e) => NotificationModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<bool> markAsRead(String notificationId) async {
    final response =
        await _apiService.put('/notifications/$notificationId/read');
    return response.success;
  }

  Future<int> getUnreadCount() async {
    final response = await _apiService.get('/notifications/unread-count');
    if (response.success && response.data != null) {
      return response.data['count'] ?? 0;
    }
    return 0;
  }
}

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type;
  final String priority;
  final bool isRead;
  final DateTime createdAt;
  final String? senderName;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.isRead,
    required this.createdAt,
    this.senderName,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'GENERAL',
      priority: json['priority'] ?? 'NORMAL',
      isRead: json['isRead'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      senderName: json['sender'] != null
          ? '${json['sender']['firstName']} ${json['sender']['lastName']}'
          : null,
    );
  }
}

final notificationsProvider =
    FutureProvider<List<NotificationModel>>((ref) async {
  return ref.read(notificationRepositoryProvider).getNotifications();
});

final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  return ref.read(notificationRepositoryProvider).getUnreadCount();
});
