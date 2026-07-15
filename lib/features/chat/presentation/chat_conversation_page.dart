import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/notify.dart';
import '../../../core/widgets/lok_fields.dart';
import '../../deals/data/deals_repository.dart';
import '../../posts/data/models/post_model.dart';
import '../data/chat_model.dart';
import 'controllers/chat_conversation_controller.dart';

class ChatConversationPage extends StatelessWidget {
  final PostUser user;
  final int? chatId; // known when coming from the inbox
  final int? postId; // known when coming from a post

  const ChatConversationPage({super.key, required this.user, this.chatId, this.postId});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(
      ChatConversationController(peer: user, initialChatId: chatId, postId: postId),
      tag: 'chat_${user.id}',
    );
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
                user.name.isEmpty ? '?' : user.name[0],
                style: TextStyle(
                    color: AppPalette.primary, fontWeight: FontWeight.w700, fontSize: 13.sp),
              ),
            ),
            SizedBox(width: 10.w),
            Text(user.name, style: TextStyle(fontSize: 16.sp)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (c.loading.value && c.messages.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (c.messages.isEmpty) {
                return Center(
                  child: Text(
                    'Say hello — this is the start of your conversation.',
                    style: TextStyle(fontSize: 12.5.sp, color: cs.onSurfaceVariant),
                  ),
                );
              }
              return ListView.builder(
                reverse: true,
                padding: EdgeInsets.all(16.w),
                itemCount: c.messages.length,
                itemBuilder: (_, i) {
                  final m = c.messages[c.messages.length - 1 - i];
                  return _Bubble(message: m);
                },
              );
            }),
          ),
          Obx(() => c.post.value == null
              ? const SizedBox.shrink()
              : _confirmBar(context, c)),
          _composer(context, c, cs),
        ],
      ),
    );
  }

  Widget _confirmBar(BuildContext context, ChatConversationController c) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _openConfirm(context, c),
          icon: Icon(Icons.handshake_outlined, size: 18.sp),
          label: const Text('Confirm agreement & continue'),
          style: ElevatedButton.styleFrom(
            minimumSize: Size(0, 46.h),
            backgroundColor: AppPalette.confirmGreen,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  void _openConfirm(BuildContext context, ChatConversationController c) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (_) => _AgreementSheet(peer: user, post: c.post.value!),
    );
  }

  Widget _composer(BuildContext context, ChatConversationController c, ColorScheme cs) {
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
            IconButton(
              onPressed: () => toast('Attachments are coming soon'),
              tooltip: 'Attach file or image',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.attach_file, color: cs.onSurfaceVariant, size: 22.sp),
            ),
            Expanded(
              child: TextField(
                controller: c.composer,
                onSubmitted: (_) => c.send(),
                decoration: InputDecoration(
                  hintText: 'Message...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Obx(
              () => GestureDetector(
                onTap: c.send,
                child: CircleAvatar(
                  radius: 22.r,
                  backgroundColor: AppPalette.primary,
                  child: c.sending.value
                      ? SizedBox(
                          width: 16.r,
                          height: 16.r,
                          child: const CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(Icons.send, color: Colors.white, size: 18.sp),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Locks in the terms agreed in chat — creates the actual deal.
class _AgreementSheet extends StatefulWidget {
  final PostUser peer;
  final ChatPostContext post;

  const _AgreementSheet({required this.peer, required this.post});

  @override
  State<_AgreementSheet> createState() => _AgreementSheetState();
}

class _AgreementSheetState extends State<_AgreementSheet> {
  final _repo = DealsRepository();
  final _cost = TextEditingController();
  final _weight = TextEditingController();
  final _receiverName = TextEditingController();
  final _receiverPhone = TextEditingController();
  DateTime? _tripDate;
  String? _payment = 'COD';
  bool _sending = false;

  @override
  void dispose() {
    _cost.dispose();
    _weight.dispose();
    _receiverName.dispose();
    _receiverPhone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cost = double.tryParse(_cost.text);
    final weight = double.tryParse(_weight.text);
    if (cost == null || weight == null || _tripDate == null) {
      toast('Cost, weight and trip date are required');
      return;
    }

    final myId = Get.find<SessionService>().user.value?.id ?? 0;
    // on a trip post the other side is the traveler; on a delivery it's the sender
    final peerIsTraveler = widget.post.type == 'TRIP';

    setState(() => _sending = true);
    try {
      await _repo.create(
        senderId: peerIsTraveler ? myId : widget.peer.id,
        travelerId: peerIsTraveler ? widget.peer.id : myId,
        postId: widget.post.id,
        wantTo: widget.post.wantTo ?? 'SEND',
        cost: cost,
        weight: weight,
        tripDate: _tripDate!,
        receiverName: _receiverName.text.trim(),
        receiverPhone: _receiverPhone.text.trim(),
        paymentMethod: _payment ?? 'COD',
      );
      if (!mounted) return;
      Navigator.pop(context);
      toast('Agreement sent — track it under Deals');
    } on AppException catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Confirm agreement', style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: 6.h),
              Text(
                'Lock in the details agreed with ${widget.peer.name} — '
                'weight, price, and dates — and move to the deal.',
                style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant, height: 1.4),
              ),
              SizedBox(height: 18.h),
              Row(
                children: [
                  Expanded(
                    child: LokTextField(
                      label: 'Agreed cost',
                      hint: 'e.g. 50',
                      icon: Icons.payments_outlined,
                      required: true,
                      keyboardType: TextInputType.number,
                      controller: _cost,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: LokTextField(
                      label: 'Weight (kg)',
                      hint: 'e.g. 2',
                      icon: Icons.scale_outlined,
                      required: true,
                      keyboardType: TextInputType.number,
                      controller: _weight,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              LokDateField(
                label: 'Trip date',
                hint: 'when it travels',
                required: true,
                value: _tripDate,
                onChanged: (d) => setState(() => _tripDate = d),
              ),
              SizedBox(height: 14.h),
              LokTextField(
                label: 'Receiver name',
                hint: 'who picks it up',
                icon: Icons.person_outline,
                controller: _receiverName,
              ),
              SizedBox(height: 14.h),
              LokTextField(
                label: 'Receiver phone',
                hint: '+216...',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                controller: _receiverPhone,
              ),
              SizedBox(height: 14.h),
              LokDropdownField(
                label: 'Payment method',
                hint: 'payment method',
                icon: Icons.credit_card,
                options: const ['COD', 'STRIPE'],
                value: _payment,
                onChanged: (v) => setState(() => _payment = v),
              ),
              SizedBox(height: 18.h),
              ElevatedButton(
                onPressed: _sending ? null : _submit,
                child: _sending
                    ? SizedBox(
                        width: 20.r,
                        height: 20.r,
                        child: const CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirm & continue'),
              ),
            ],
          ),
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
