import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/notify.dart';
import '../../../core/utils/verify_gate.dart';
import '../../../core/widgets/lok_fields.dart';
import '../../deals/data/deals_repository.dart';
import '../../deals/presentation/deal_details_page.dart';
import '../../posts/data/models/post_model.dart';
import '../data/chat_model.dart';
import 'controllers/chat_conversation_controller.dart';
import 'widgets/report_profile_sheet.dart';

class ChatConversationPage extends StatelessWidget {
  final PostUser user;
  final int? chatId; // known when coming from the inbox
  final int? postId; // known when coming from a post

  const ChatConversationPage({
    super.key,
    required this.user,
    this.chatId,
    this.postId,
  });

  @override
  Widget build(BuildContext context) {
    final c = Get.put(
      ChatConversationController(
        peer: user,
        initialChatId: chatId,
        postId: postId,
      ),
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
                  color: AppPalette.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16.sp),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => ReportProfileSheet.show(
              context,
              userId: user.id,
              userName: user.name,
            ),
            icon: Icon(
              Icons.flag_outlined,
              size: 15.sp,
              color: AppPalette.primary,
            ),
            label: Text(
              'Report',
              style: TextStyle(fontSize: 12.sp, color: AppPalette.primary),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // route being discussed, mirroring the web chat header
          Obx(
            () => c.post.value == null
                ? const SizedBox.shrink()
                : _routeStrip(context, c.post.value!),
          ),
          Expanded(
            child: Obx(() {
              if (c.loading.value && c.messages.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (c.messages.isEmpty) {
                return Center(
                  child: Text(
                    'Say hello — this is the start of your conversation.',
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return ListView.builder(
                reverse: true,
                padding: EdgeInsets.all(16.w),
                itemCount: c.messages.length,
                itemBuilder: (_, i) {
                  final m = c.messages[c.messages.length - 1 - i];
                  return m.isSystem
                      ? _SystemBubble(message: m)
                      : _Bubble(message: m);
                },
              );
            }),
          ),
          Obx(() {
            // once an agreement exists the bar links to it instead of
            // disappearing (and instead of allowing a duplicate deal)
            if (c.deal.value != null) return _dealBar(context, c);
            return c.post.value == null
                ? const SizedBox.shrink()
                : _confirmBar(context, c);
          }),
          _composer(context, c, cs),
        ],
      ),
    );
  }

  Widget _routeStrip(BuildContext context, ChatPostContext post) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              post.from,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
          if (post.beforeDate != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AppPalette.primary,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                'Before ${post.beforeDate}',
                style: TextStyle(fontSize: 9.5.sp, color: Colors.white),
              ),
            ),
          Expanded(
            child: Text(
              post.to,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
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

  // an agreement already exists for this chat — offer it instead of a duplicate
  Widget _dealBar(BuildContext context, ChatConversationController c) {
    final cs = Theme.of(context).colorScheme;
    final status = c.deal.value?.status ?? '';
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _openDeal(c),
          icon: Icon(Icons.receipt_long_outlined, size: 18.sp),
          label: Text(status.isEmpty ? 'Show Deal' : 'Show Deal · $status'),
          style: OutlinedButton.styleFrom(
            minimumSize: Size(0, 46.h),
            foregroundColor: AppPalette.confirmGreen,
            side: const BorderSide(color: AppPalette.confirmGreen),
          ),
        ),
      ),
    );
  }

  Future<void> _openDeal(ChatConversationController c) async {
    final id = c.deal.value?.id;
    if (id == null) return;
    try {
      final deal = await DealsRepository().getById(id);
      await Get.to(() => DealDetailsPage(deal: deal));
      await c.reloadContext(); // status may have moved on while it was open
    } on AppException catch (e) {
      toastError(e);
    }
  }

  void _openConfirm(BuildContext context, ChatConversationController c) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      // leave a strip of backdrop so tapping outside still dismisses
      constraints: BoxConstraints(maxHeight: 0.92.sh),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (_) => _AgreementSheet(peer: user, post: c.post.value!),
    );
  }

  Widget _composer(
    BuildContext context,
    ChatConversationController c,
    ColorScheme cs,
  ) {
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
              onPressed: c.sendAttachment,
              tooltip: 'Attach file or image',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.attach_file,
                color: cs.onSurfaceVariant,
                size: 22.sp,
              ),
            ),
            Expanded(
              child: TextField(
                controller: c.composer,
                onSubmitted: (_) => c.send(),
                decoration: InputDecoration(
                  hintText: 'Message...',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
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
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
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
  final _itemValue = TextEditingController();
  final _weight = TextEditingController();
  final _itemName = TextEditingController();
  final _itemLink = TextEditingController();
  final _itemDescription = TextEditingController();
  final _receiverName = TextEditingController();
  final _receiverPhone = TextEditingController();
  DateTime? _tripDate;
  DateTime? _arrivalDate;
  String? _payment = 'Card (Stripe)';
  bool _securityDeposit = false;
  bool _sending = false;
  final List<XFile> _photos = [];

  bool get _isBuyAndDeliver => widget.post.wantTo == 'BUY_AND_DELIVER';
  bool get _isStripe => _payment == 'Card (Stripe)';

  @override
  void dispose() {
    _cost.dispose();
    _itemValue.dispose();
    _weight.dispose();
    _itemName.dispose();
    _itemLink.dispose();
    _itemDescription.dispose();
    _receiverName.dispose();
    _receiverPhone.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final imgs = await ImagePicker().pickMultiImage(
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (imgs.isNotEmpty && mounted) {
      setState(
        () => _photos
          ..clear()
          ..addAll(imgs.take(5)),
      );
    }
  }

  Future<void> _submit() async {
    final cost = double.tryParse(_cost.text);
    final itemValue = double.tryParse(_itemValue.text);
    final weight = double.tryParse(_weight.text);
    if (cost == null || weight == null || _tripDate == null) {
      toast('Cost, weight and trip date are required');
      return;
    }
    if (itemValue == null) {
      toast('Add the estimated item value');
      return;
    }
    if (_arrivalDate == null) {
      toast('Pick the arrival date');
      return;
    }
    if (_arrivalDate!.isBefore(_tripDate!)) {
      toast('Arrival must be on or after the trip date');
      return;
    }
    // server rule: arrival within 3 days of the trip date
    if (_arrivalDate!.difference(_tripDate!).inDays > 3) {
      toast('Arrival must be within 3 days of the trip date');
      return;
    }
    // buy-and-deliver needs the item identified and paid through Stripe
    if (_isBuyAndDeliver && _itemName.text.trim().isEmpty) {
      toast('Add the item name');
      return;
    }
    if (_isBuyAndDeliver && !_isStripe) {
      toast('Buy-and-deliver deals must be paid by card');
      return;
    }
    // a security deposit is a card hold — impossible with cash
    if (_securityDeposit && !_isStripe) {
      toast('A security deposit needs card payment');
      return;
    }
    // the API rejects the deal without them, so catch it here
    if (_receiverName.text.trim().isEmpty ||
        _receiverPhone.text.trim().isEmpty) {
      toast('Add the receiver name and phone');
      return;
    }
    // identity verification is required to create a deal (not to chat)
    if (!await requireVerified()) return;
    if (!mounted) return;

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
        itemEstimatedCost: itemValue,
        weight: weight,
        tripDate: _tripDate!,
        arrivalDate: _arrivalDate!,
        sdRequired: _securityDeposit,
        itemName: _itemName.text.trim(),
        itemLink: _itemLink.text.trim(),
        itemDescription: _itemDescription.text.trim(),
        receiverName: _receiverName.text.trim(),
        receiverPhone: _receiverPhone.text.trim(),
        attachFilePaths: _photos.map((x) => x.path).toList(),
        // API enum value — the label shown in the dropdown is friendlier
        paymentMethod: _isStripe ? 'STRIPE' : 'CASH_ON_DELIVERY',
      );
      if (!mounted) return;
      Navigator.pop(context);
      toast('Agreement sent — track it under Deals');
      // flip the chat's action bar over to the new agreement straight away
      if (Get.isRegistered<ChatConversationController>()) {
        await Get.find<ChatConversationController>().reloadContext();
      }
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // pinned header: the body scrolls, so drag-to-dismiss never fires —
            // without this there's no way out of a full-height sheet
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 6.w, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Confirm agreement',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    tooltip: 'Close',
                    icon: Icon(
                      Icons.close,
                      size: 22.sp,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 24.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lock in the details agreed with ${widget.peer.name} — '
                      'weight, price, and dates — and move to the deal.',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 18.h),
                    Row(
                      children: [
                        Expanded(
                          child: LokTextField(
                            label: 'Traveler profit',
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
                    LokTextField(
                      label: 'Item value',
                      hint: 'what the item is worth',
                      icon: Icons.sell_outlined,
                      required: true,
                      keyboardType: TextInputType.number,
                      controller: _itemValue,
                    ),
                    SizedBox(height: 14.h),
                    LokTextField(
                      label: _isBuyAndDeliver
                          ? 'Item name'
                          : 'Item name (optional)',
                      hint: 'what is being carried',
                      icon: Icons.inventory_2_outlined,
                      required: _isBuyAndDeliver,
                      controller: _itemName,
                    ),
                    SizedBox(height: 14.h),
                    LokTextField(
                      label: 'Item link (optional)',
                      hint: 'store / product page URL',
                      icon: Icons.link,
                      keyboardType: TextInputType.url,
                      controller: _itemLink,
                    ),
                    SizedBox(height: 14.h),
                    LokTextField(
                      label: 'Item description (optional)',
                      hint: 'color, size, packaging...',
                      icon: Icons.notes_outlined,
                      maxLines: 3,
                      controller: _itemDescription,
                    ),
                    SizedBox(height: 14.h),
                    // item photos travel with the deal so both sides agree on
                    // what is being carried (website: attachFiles[])
                    GestureDetector(
                      onTap: _pickPhotos,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 12.h,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: cs.outline),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              size: 18.sp,
                              color: cs.onSurfaceVariant,
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Text(
                                _photos.isEmpty
                                    ? 'Add item photos (optional)'
                                    : '${_photos.length} photo${_photos.length > 1 ? 's' : ''} selected',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (_photos.isNotEmpty)
                              GestureDetector(
                                onTap: () => setState(_photos.clear),
                                child: Icon(
                                  Icons.close,
                                  size: 16.sp,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
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
                    LokDateField(
                      label: 'Arrival date',
                      hint: 'when it lands',
                      required: true,
                      value: _arrivalDate,
                      onChanged: (d) => setState(() => _arrivalDate = d),
                    ),
                    SizedBox(height: 14.h),
                    LokCheckbox(
                      label: 'Require a security deposit from the traveler',
                      value: _securityDeposit,
                      onChanged: (v) => setState(() => _securityDeposit = v),
                    ),
                    SizedBox(height: 14.h),
                    LokTextField(
                      label: 'Receiver name',
                      hint: 'who picks it up',
                      icon: Icons.person_outline,
                      required: true,
                      controller: _receiverName,
                    ),
                    SizedBox(height: 14.h),
                    LokTextField(
                      label: 'Receiver phone',
                      hint: '+216...',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      required: true,
                      controller: _receiverPhone,
                    ),
                    SizedBox(height: 14.h),
                    LokDropdownField(
                      label: 'Payment method',
                      hint: 'payment method',
                      icon: Icons.credit_card,
                      options: const ['Card (Stripe)', 'Cash on delivery'],
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
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Confirm & continue'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Images preview inline; anything else shows as a tappable file chip.
class _Attachment extends StatelessWidget {
  final String url;
  final bool me;
  final String? mime;
  final String? name;
  const _Attachment({
    required this.url,
    required this.me,
    this.mime,
    this.name,
  });

  // media URLs end in /stream, so the extension check alone never matches —
  // trust the mime type first and fall back to the name/url
  bool get _isImage {
    if (mime != null && mime!.isNotEmpty) {
      return mime!.toLowerCase().startsWith('image/');
    }
    final probe = name ?? url;
    return RegExp(
      r'\.(png|jpe?g|gif|webp|bmp)(\?|$)',
      caseSensitive: false,
    ).hasMatch(probe);
  }

  @override
  Widget build(BuildContext context) {
    final fg = me ? Colors.white : Theme.of(context).colorScheme.onSurface;

    if (_isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10.r),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 0.52.sw,
          fit: BoxFit.cover,
          placeholder: (_, __) => SizedBox(
            width: 0.52.sw,
            height: 120.h,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (_, __, ___) => _fileChip(fg, 'Image unavailable'),
        ),
      );
    }
    // the url's last segment is "stream" — show the real filename when we have it
    final label = (name != null && name!.isNotEmpty)
        ? name!
        : url.split('/').last.split('?').first;
    return _fileChip(fg, label);
  }

  Widget _fileChip(Color fg, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.insert_drive_file_outlined, size: 16.sp, color: fg),
        SizedBox(width: 6.w),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.sp,
              color: fg,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

// Deal events the backend drops into the thread — full-width, with a shortcut
// to the deal they refer to.
class _SystemBubble extends StatelessWidget {
  final ChatMessage message;
  const _SystemBubble({required this.message});

  Future<void> _openDeal() async {
    final id = message.dealId;
    if (id == null) return;
    try {
      final deal = await DealsRepository().getById(id);
      Get.to(() => DealDetailsPage(deal: deal));
    } on AppException catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppPalette.intlAccent.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        children: [
          Text(
            message.text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: Colors.white, height: 1.4),
          ),
          if (message.dealId != null) ...[
            SizedBox(height: 10.h),
            ElevatedButton(
              onPressed: _openDeal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.navy,
                foregroundColor: Colors.white,
                minimumSize: Size(0, 34.h),
                padding: EdgeInsets.symmetric(horizontal: 18.w),
              ),
              child: Text('Click Here', style: TextStyle(fontSize: 12.sp)),
            ),
          ],
          SizedBox(height: 6.h),
          Text(
            chatTime(message.time),
            style: TextStyle(
              fontSize: 9.sp,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
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
            if (message.attachmentUrl != null) ...[
              _Attachment(
                url: message.attachmentUrl!,
                me: me,
                mime: message.attachmentMime,
                name: message.attachmentName,
              ),
              if (message.text.isNotEmpty) SizedBox(height: 6.h),
            ],
            if (message.text.isNotEmpty)
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
              chatTime(message.time),
              style: TextStyle(
                fontSize: 9.sp,
                color: me
                    ? Colors.white.withValues(alpha: 0.8)
                    : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
