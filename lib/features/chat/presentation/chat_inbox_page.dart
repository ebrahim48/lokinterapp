import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/chat_gate.dart';
import '../../../core/utils/format.dart';
import 'controllers/chat_inbox_controller.dart';

class ChatInboxPage extends StatelessWidget {
  const ChatInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ChatInboxController());
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: Obx(() {
        if (c.loading.value && c.conversations.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.error.value != null && c.conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(c.error.value!,
                    style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
                TextButton(onPressed: c.load, child: const Text('Retry')),
              ],
            ),
          );
        }
        if (c.conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline, size: 44.sp, color: cs.onSurfaceVariant),
                SizedBox(height: 12.h),
                Text('No conversations yet',
                    style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: c.load,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            itemCount: c.conversations.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, indent: 76.w, color: cs.outline),
            itemBuilder: (_, i) {
              final conv = c.conversations[i];
              return ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                onTap: () => openChat(conv.user, chatId: conv.chatId),
                leading: CircleAvatar(
                  radius: 24.r,
                  backgroundColor: AppPalette.primary.withValues(alpha: 0.15),
                  child: Text(
                    conv.user.name.isEmpty ? '?' : conv.user.name[0],
                    style: const TextStyle(
                        color: AppPalette.primary, fontWeight: FontWeight.w700),
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(conv.user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700)),
                    ),
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
                    Text(chatTime(conv.time),
                        style: TextStyle(fontSize: 10.sp, color: cs.onSurfaceVariant)),
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
      }),
    );
  }
}
