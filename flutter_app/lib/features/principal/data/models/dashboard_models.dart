import 'package:equatable/equatable.dart';

class DashboardPostModel extends Equatable {
  final String id;
  final String title;
  final String content;
  final String type;
  final String? authorName;
  final DateTime createdAt;
  final List<String> mediaUrls;
  final bool isPinned;
  final bool isPublished;

  const DashboardPostModel({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    this.authorName,
    required this.createdAt,
    this.mediaUrls = const [],
    this.isPinned = false,
    this.isPublished = true,
  });

  factory DashboardPostModel.fromJson(Map<String, dynamic> json) {
    String? author;
    if (json['author'] != null) {
      author = '${json['author']['firstName']} ${json['author']['lastName']}';
    }

    return DashboardPostModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      type: json['type'] ?? 'UPDATE',
      authorName: author,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      mediaUrls:
          json['mediaUrls'] != null ? List<String>.from(json['mediaUrls']) : [],
      isPinned: json['isPinned'] ?? false,
      isPublished: json['isPublished'] ?? true,
    );
  }

  @override
  List<Object?> get props => [id, title, type, createdAt];
}

class UpcomingEventModel extends Equatable {
  final String id;
  final String title;
  final String? content;
  final DateTime date;

  const UpcomingEventModel({
    required this.id,
    required this.title,
    this.content,
    required this.date,
  });

  factory UpcomingEventModel.fromJson(Map<String, dynamic> json) {
    return UpcomingEventModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'],
      date: json['createdAt'] != null
          ? DateTime.parse(
              json['createdAt']) // Backend uses createdAt if no specific date
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, title, date];
}
