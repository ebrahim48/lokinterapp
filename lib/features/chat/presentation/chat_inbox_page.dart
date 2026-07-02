import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../data/chat_model.dart';
import 'chat_conversation_page.dart';

class ChatInboxPage extends StatelessWidget {
  const ChatInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: ListView.separated(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        itemCount: mockConversations.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, indent: 76.w, color: cs.outline),
        itemBuilder: (_, i) {
          final conv = mockConversations[i];
          return ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            onTap: () => Get.to(() => ChatConversationPage(conversation: conv)),
            leading: CircleAvatar(
              radius: 24.r,
              backgroundColor: AppPalette.primary.withValues(alpha: 0.15),
              child: Text(
                conv.user.name[0],
                style: const TextStyle(
                    color: AppPalette.primary, fontWeight: FontWeight.w700),
              ),
            ),
            title: Row(
              children: [
                Text(conv.user.name,
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700)),
                if (conv.user.verified) ...[
                  SizedBox(width: 4.w),
                  Icon(Icons.verified, size: 14.sp, color: AppPalette.verified),
                ],
              ],
            ),
            subtitle: Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Text(
                conv.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(conv.time, style: TextStyle(fontSize: 10.sp, color: cs.onSurfaceVariant)),
                SizedBox(height: 6.h),
                if (conv.unread > 0)
                  Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: const BoxDecoration(
                        color: AppPalette.primary, shape: BoxShape.circle),
                    child: Text(
                      '${conv.unread}',
                      style: TextStyle(
                          color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
