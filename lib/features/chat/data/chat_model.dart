import '../../../core/utils/media_url.dart';
import '../../posts/data/models/post_model.dart';

class ChatMessage {
  final int id;
  final String text;
  final bool fromMe;
  final String time;
  final String? attachmentUrl;

  const ChatMessage({
    this.id = 0,
    required this.text,
    required this.fromMe,
    required this.time,
    this.attachmentUrl,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, int myUserId) {
    final senderId = json['userId'] ?? json['fromId'] ?? json['senderId'] ?? 0;
    return ChatMessage(
      id: json['id'] ?? 0,
      text: json['message'] ?? '',
      fromMe: senderId == myUserId,
      time: (json['time'] ?? json['createdAt'] ?? json['created_at'] ?? '').toString(),
      attachmentUrl:
          fixMediaUrl(json['fileUrl'] ?? json['file']?['url'] ?? json['attachFile']?['url']),
    );
  }
}

class Conversation {
  final int chatId;
  final PostUser user;
  final String lastMessage;
  final String time;
  final int unread;

  const Conversation({
    required this.chatId,
    required this.user,
    this.lastMessage = '',
    this.time = '',
    this.unread = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        chatId: json['id'] ?? 0,
        user: PostUser.fromJson(Map<String, dynamic>.from(json['user'] ?? {})),
        lastMessage: json['lastMessage'] ?? '',
        time: json['lastTimeMessage'] ?? '',
        unread: json['newMessages'] ?? 0,
      );
}

// what the chat screen needs to know about the post being discussed
class ChatPostContext {
  final int id;
  final String type; // TRIP or DELIVER
  final String? wantTo;

  const ChatPostContext({required this.id, required this.type, this.wantTo});

  static ChatPostContext? fromJson(dynamic json) {
    if (json is! Map || json['id'] == null) return null;
    return ChatPostContext(
      id: json['id'],
      type: json['type'] ?? 'TRIP',
      wantTo: json['wantTo'],
    );
  }
}
