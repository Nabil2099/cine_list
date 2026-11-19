import 'package:equatable/equatable.dart';

/// Single chat message in the CineList AI conversation.
class ChatMessageModel extends Equatable {
  const ChatMessageModel({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.imageBase64,
    this.imageMimeType,
  });

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: (map['id'] as String?) ?? '',
      text: (map['text'] as String?) ?? '',
      isUser: map['isUser'] == true,
      timestamp:
          DateTime.tryParse((map['timestamp'] as String?) ?? '') ??
          DateTime.now(),
      isError: map['isError'] == true,
      imageBase64: map['imageBase64'] as String?,
      imageMimeType: map['imageMimeType'] as String?,
    );
  }

  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final String? imageBase64;
  final String? imageMimeType;

  bool get hasImage => imageBase64 != null && imageBase64!.isNotEmpty;

  ChatMessageModel copyWith({
    String? text,
    bool? isError,
    String? imageBase64,
    String? imageMimeType,
  }) {
    return ChatMessageModel(
      id: id,
      text: text ?? this.text,
      isUser: isUser,
      timestamp: timestamp,
      isError: isError ?? this.isError,
      imageBase64: imageBase64 ?? this.imageBase64,
      imageMimeType: imageMimeType ?? this.imageMimeType,
    );
  }

  Map<String, dynamic> toMap() {
    final persistImage =
        imageBase64 != null && imageBase64!.length <= 350000;
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'isError': isError,
      if (persistImage) 'imageBase64': imageBase64,
      if (persistImage && imageMimeType != null) 'imageMimeType': imageMimeType,
    };
  }

  @override
  List<Object?> get props => [
    id,
    text,
    isUser,
    timestamp,
    isError,
    imageBase64,
    imageMimeType,
  ];
}
