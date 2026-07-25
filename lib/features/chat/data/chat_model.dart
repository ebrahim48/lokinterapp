import '../../../core/utils/media_url.dart';
import '../../posts/data/models/post_model.dart';

class ChatMessage {
  final int id;
  final String text;
  final bool fromMe;
  final String time;
  final String? attachmentUrl;
  // media URLs end in /stream with no extension, so the mime type is the only
  // reliable way to tell an image from a document
  final String? attachmentMime;
  final String? attachmentName;
  // system messages announce deal events and link back to the deal
  final bool isSystem;
  final String? systemType; // e.g. DEAL_ACCEPT
  final int? dealId;

  const ChatMessage({
    this.id = 0,
    required this.text,
    required this.fromMe,
    required this.time,
    this.attachmentUrl,
    this.attachmentMime,
    this.attachmentName,
    this.isSystem = false,
    this.systemType,
    this.dealId,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, int myUserId) {
    final senderId = json['userId'] ?? json['fromId'] ?? json['senderId'];
    final data = json['data'];
    final file = json['file'] ?? json['attachFile'];
    return ChatMessage(
      id: json['id'] ?? 0,
      text: json['message'] ?? '',
      // system rows have a null userId, so they'd otherwise read as "mine"
      fromMe: senderId != null && senderId == myUserId,
      time: (json['time'] ?? json['createdAt'] ?? json['created_at'] ?? '').toString(),
      attachmentUrl:
          fixMediaUrl(json['fileUrl'] ?? (file is Map ? file['url'] : null)),
      attachmentMime: file is Map ? file['mimeType'] as String? : null,
      attachmentName: file is Map ? (file['fileName'] ?? file['name']) as String? : null,
      isSystem: json['type'] == 'system',
      systemType: json['systemMessageType'],
      // data.id arrives as a string
      dealId: data is Map ? int.tryParse('${data['id']}') : null,
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

  Conversation copyWith({String? lastMessage, String? time, int? unread}) => Conversation(
        chatId: chatId,
        user: user,
        lastMessage: lastMessage ?? this.lastMessage,
        time: time ?? this.time,
        unread: unread ?? this.unread,
      );

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        chatId: json['id'] ?? 0,
        user: PostUser.fromJson(Map<String, dynamic>.from(json['user'] ?? {})),
        lastMessage: json['lastMessage'] ?? '',
        time: json['lastTimeMessage'] ?? '',
        unread: json['newMessages'] ?? 0,
      );
}

// getChatDetails returns the agreement alongside the post once one exists —
// the chat screen swaps "Confirm agreement" for a link to it
class ChatDealRef {
  final int id;
  final String status;

  const ChatDealRef({required this.id, this.status = ''});

  static ChatDealRef? fromJson(dynamic json) {
    if (json is! Map || json['id'] == null) return null;
    final id = json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}');
    if (id == null) return null;
    return ChatDealRef(id: id, status: '${json['status'] ?? ''}');
  }
}

// what the chat screen needs to know about the post being discussed
class ChatPostContext {
  final int id;
  final String type; // TRIP or DELIVER
  final String? wantTo;
  final String from;
  final String to;
  final String? beforeDate;

  const ChatPostContext({
    required this.id,
    required this.type,
    this.wantTo,
    this.from = '',
    this.to = '',
    this.beforeDate,
  });

  static ChatPostContext? fromJson(dynamic json) {
    if (json is! Map || json['id'] == null) return null;
    return ChatPostContext(
      id: json['id'],
      type: json['type'] ?? 'TRIP',
      wantTo: json['wantTo'],
      from: _place(json['fromCity'], json['fromCountry']),
      to: _place(json['toCity'], json['toCountry']),
      beforeDate: json['beforeDate'],
    );
  }

  // city wins when set; both come as objects, and empty relations arrive as []
  static String _place(dynamic city, dynamic country) {
    for (final v in [city, country]) {
      if (v is Map && (v['name'] ?? '').toString().isNotEmpty) return v['name'];
      if (v is String && v.isNotEmpty) return v;
    }
    return '';
  }
}
