import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_palette.dart';
import '../data/chat_model.dart';

class ChatConversationPage extends StatelessWidget {
  final Conversation conversation;
  const ChatConversationPage({super.key, required this.conversation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16.r,
              backgroundColor: AppPalette.primary.withValues(alpha: 0.15),
              child: Text(
                conversation.user.name[0],
                style: TextStyle(
                    color: AppPalette.primary, fontWeight: FontWeight.w700, fontSize: 13.sp),
              ),
            ),
            SizedBox(width: 10.w),
            Text(conversation.user.name, style: TextStyle(fontSize: 16.sp)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: EdgeInsets.all(16.w),
              itemCount: conversation.messages.length,
              itemBuilder: (_, i) {
                final m = conversation.messages[conversation.messages.length - 1 - i];
                return _Bubble(message: m);
              },
            ),
          ),
          _composer(context, cs),
        ],
      ),
    );
  }

  Widget _composer(BuildContext context, ColorScheme cs) {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 12.h),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Message...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            CircleAvatar(
              radius: 22.r,
              backgroundColor: AppPalette.primary,
              child: Icon(Icons.send, color: Colors.white, size: 18.sp),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final me = message.fromMe;
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        constraints: BoxConstraints(maxWidth: 0.72.sw),
        decoration: BoxDecoration(
          color: me ? AppPalette.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(14.r),
            topRight: Radius.circular(14.r),
            bottomLeft: Radius.circular(me ? 14.r : 2.r),
            bottomRight: Radius.circular(me ? 2.r : 14.r),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 13.sp,
                color: me ? Colors.white : cs.onSurface,
                height: 1.3,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              message.time,
              style: TextStyle(
                fontSize: 9.sp,
                color: me ? Colors.white.withValues(alpha: 0.8) : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
