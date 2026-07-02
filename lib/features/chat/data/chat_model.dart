import '../../posts/data/models/post_model.dart';

class ChatMessage {
  final String text;
  final bool fromMe;
  final String time;

  const ChatMessage({required this.text, required this.fromMe, required this.time});
}

class Conversation {
  final PostUser user;
  final String lastMessage;
  final String time;
  final int unread;
  final List<ChatMessage> messages;

  const Conversation({
    required this.user,
    required this.lastMessage,
    required this.time,
    this.unread = 0,
    this.messages = const [],
  });
}

const _thread = [
  ChatMessage(text: 'Hi! I saw your trip to Tunis, is there space left?', fromMe: true, time: '09:31'),
  ChatMessage(text: 'Yes, 8 kg available. What do you need to send?', fromMe: false, time: '09:33'),
  ChatMessage(text: 'A small parcel, about 2 kg. Shein order.', fromMe: true, time: '09:34'),
  ChatMessage(text: 'Sounds good. I can carry it for TND 50.', fromMe: false, time: '09:36'),
  ChatMessage(text: 'Deal! I will send the agreement now.', fromMe: true, time: '09:37'),
];

final mockConversations = <Conversation>[
  const Conversation(
    user: PostUser(name: 'Ahmed R.', verified: true, rating: 4.7),
    lastMessage: 'Deal! I will send the agreement now.',
    time: '2m',
    unread: 2,
    messages: _thread,
  ),
  const Conversation(
    user: PostUser(name: 'Lina B.', verified: true, rating: 4.9),
    lastMessage: 'Perfect, see you on the 3rd.',
    time: '1h',
    messages: _thread,
  ),
  const Conversation(
    user: PostUser(name: 'Karim T.', rating: 4.1),
    lastMessage: 'Can you do 1.5 kg instead?',
    time: 'Yesterday',
    messages: _thread,
  ),
];
