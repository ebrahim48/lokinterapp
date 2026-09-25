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
import '../../../core/utils/phone_gate.dart';
import '../../../core/utils/verify_gate.dart';
import '../../../core/widgets/image_viewer.dart';
import '../../../core/widgets/lok_fields.dart';
import '../../deals/data/deals_repository.dart';
import '../../deals/presentation/widgets/currency_converter.dart';
import '../../deals/presentation/deal_details_page.dart';
import '../../lookups/data/lookup_models.dart';
import '../../lookups/data/lookups_repository.dart';
import '../../posts/data/models/post_model.dart';
import '../data/chat_model.dart';
import 'controllers/chat_conversation_controller.dart';
import 'widgets/report_profile_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../reviews/presentation/user_reviews_page.dart';

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
    // the controller is cached per peer, so reopening this conversation from a
    // different post (or from the inbox, which carries none) has to re-read the
    // context with that postId — otherwise it stays on the first post's roles
    if (c.postId != postId) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => c.switchPost(postId));
    }
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        // tapping the header opens the other person's public profile
        title: GestureDetector(
          onTap: user.id == 0
              ? null
              : () => Get.to(() =>
                  UserReviewsPage(userId: user.id, userName: user.name)),
          child: Row(
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
              'report'.tr,
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
                    'say_hello_this_is_the_start_of_your_conversation'.tr,
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
            final post = c.post.value;
            final deal = c.deal.value;
            final myId = Get.find<SessionService>().user.value?.id ?? 0;

            // no post in this chat → no deal actions at all
            if (post == null) return const SizedBox.shrink();

            // Exactly one of these ever shows, so the two sides of a chat can
            // never both propose: only the deal SENDER gets Confirm (the
            // delivery creator, or the trip finder), and only while no deal is
            // live. Anyone else with a deal gets its status button instead.
            if (post.canRequestDeal(myId, deal?.status)) {
              return _confirmBar(context, c);
            }
            if (deal != null) return _dealBar(context, c);
            return const SizedBox.shrink();
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
                // website (from-to): only a DELIVER post prefixes "Before"
                post.isDeliver
                    ? 'Before ${post.beforeDate}'
                    : '${post.beforeDate}',
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
          onPressed: () => _startConfirm(context, c),
          icon: Icon(Icons.handshake_outlined, size: 18.sp),
          label: Text('confirm_agreement_continue'.tr),
          style: ElevatedButton.styleFrom(
            minimumSize: Size(0, 46.h),
            backgroundColor: AppPalette.confirmGreen,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  // an agreement already exists for this chat — offer it instead of a duplicate.
  // Labels and colours mirror the website's deals-actions buttons.
  Widget _dealBar(BuildContext context, ChatConversationController c) {
    final cs = Theme.of(context).colorScheme;
    final status = c.deal.value?.status ?? '';
    final (label, colour) = switch (status) {
      // same amber the deal status badge uses for PENDING
      'PENDING' => ('Deal Pending', const Color(0xFF854D0E)),
      'ACCEPTED' => ('Deal accepted', AppPalette.confirmGreen),
      'OUTGOING' => ('Deal Ongoing', AppPalette.intlAccent),
      'COMPLETED' => ('Completed Deal', AppPalette.confirmGreen),
      'DISPUTED' => ('View Dispute', AppPalette.primary),
      'CANCELED' || 'CANCELLED' => ('Deal Canceled', AppPalette.grey),
      'REJECTED' => ('Deal Rejected', AppPalette.grey),
      _ => ('Show Deal', AppPalette.confirmGreen),
    };
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
          label: Text(label),
          style: OutlinedButton.styleFrom(
            minimumSize: Size(0, 46.h),
            foregroundColor: colour,
            side: BorderSide(color: colour),
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

  // the sender enters the agreement here, so identity is checked BEFORE the
  // form opens — not after they've filled everything in
  Future<void> _startConfirm(
      BuildContext context, ChatConversationController c) async {
    if (!await requirePhoneVerified(action: 'create a deal')) return;
    if (!await requireVerified()) return;
    if (!context.mounted) return;
    _openConfirm(context, c);
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
              tooltip: 'attach_file_or_image'.tr,
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
  String? _payment = 'Pay Online';
  bool _securityDeposit = false;
  bool _sending = false;
  final List<XFile> _photos = [];

  // receiver country drives the phone prefix (website: the country picker)
  final _lookups = LookupsRepository();
  List<Country> _countries = [];
  String? _receiverCountry;

  // the sender chooses what they want (website: the "I want to" dropdown),
  // seeded from the post — each choice shows its own linked fields
  static const _sendLabel = 'Deliver Ready Items';
  static const _buyLabel = 'Buy for Me and Deliver';
  late String _wantTo =
      widget.post.wantTo == 'BUY_AND_DELIVER' ? _buyLabel : _sendLabel;

  bool get _isBuyAndDeliver => _wantTo == _buyLabel;
  bool get _isStripe => _payment == 'Pay Online';

  List<String> get _countryNames => _countries.map((e) => e.name).toList();

  @override
  void initState() {
    super.initState();
    _lookups.countries().then((list) {
      if (mounted) setState(() => _countries = list);
    }).catchError((_) {});
  }

  // picking a country stamps the matching dial code onto the phone field,
  // same as the website's receiver-country picker
  void _onReceiverCountry(String name) {
    final c = _countries.firstWhereOrNull((e) => e.name == name);
    setState(() {
      _receiverCountry = name;
      if (c != null && c.phoneCode.isNotEmpty) {
        _receiverPhone.text = '+${c.phoneCode}';
        _receiverPhone.selection = TextSelection.fromPosition(
          TextPosition(offset: _receiverPhone.text.length),
        );
      }
    });
  }

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
      toast('cost_weight_and_trip_date_are_required'.tr);
      return;
    }
    // website rule: item value only required for a card-paid buy-and-deliver or
    // a card-paid send with a security deposit; cash deals send 0
    final itemValueRequired = _isStripe && (_isBuyAndDeliver || _securityDeposit);
    if (itemValueRequired && (itemValue == null || itemValue <= 0)) {
      toast(_isBuyAndDeliver ? 'Add the item value' : 'Add the security deposit amount');
      return;
    }
    if (_arrivalDate == null) {
      toast('pick_the_arrival_date'.tr);
      return;
    }
    if (_arrivalDate!.isBefore(_tripDate!)) {
      toast('arrival_must_be_on_or_after_the_trip_date'.tr);
      return;
    }
    // server rule: arrival within 3 days of the trip date
    if (_arrivalDate!.difference(_tripDate!).inDays > 3) {
      toast('arrival_must_be_within_3_days_of_the_trip_date'.tr);
      return;
    }
    // buy-and-deliver needs the item named, linked and paid through Stripe
    if (_isBuyAndDeliver && _itemName.text.trim().isEmpty) {
      toast('add_the_item_name'.tr);
      return;
    }
    if (_isBuyAndDeliver && _itemLink.text.trim().isEmpty) {
      toast('add_the_item_link'.tr);
      return;
    }
    if (_isBuyAndDeliver && !_isStripe) {
      toast('buy_and_deliver_deals_must_be_paid_by_card'.tr);
      return;
    }
    // a security deposit is a card hold — impossible with cash
    if (_securityDeposit && !_isStripe) {
      toast('a_security_deposit_needs_card_payment'.tr);
      return;
    }
    // the API rejects the deal without them, so catch it here
    if (_receiverName.text.trim().isEmpty ||
        _receiverPhone.text.trim().isEmpty) {
      toast('add_the_receiver_name_and_phone'.tr);
      return;
    }
    // country picker drives the phone prefix (skip only if the list never loaded)
    if (_countries.isNotEmpty && _receiverCountry == null) {
      toast('pick_the_receiver_country'.tr);
      return;
    }

    // only the sender can open this form, so the current user is the sender
    // and the chat peer is the traveler
    final myId = Get.find<SessionService>().user.value?.id ?? 0;

    setState(() => _sending = true);
    try {
      await _repo.create(
        senderId: myId,
        travelerId: widget.peer.id,
        postId: widget.post.id,
        wantTo: _isBuyAndDeliver ? 'BUY_AND_DELIVER' : 'SEND',
        cost: cost,
        itemEstimatedCost: itemValue ?? 0,
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
      // flip the chat's action bar over to the new agreement before closing,
      // so the button is already "Deal Pending" when the sheet disappears.
      // The controller is registered per peer, so the tag is required — without
      // it the lookup silently misses and the bar only updated on a manual
      // refresh.
      final tag = 'chat_${widget.peer.id}';
      if (Get.isRegistered<ChatConversationController>(tag: tag)) {
        await Get.find<ChatConversationController>(tag: tag).reloadContext();
      }
      if (!mounted) return;
      Navigator.pop(context);
      toast('agreement_sent_track_it_under_deals'.tr);
    } on AppException catch (e) {
      // the server has the last word on verification
      if (!maybeKycPrompt(e)) toastError(e);
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
                      'confirm_agreement'.tr,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    tooltip: 'close'.tr,
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
                    // I want to: Deliver Ready Items vs Buy for Me and Deliver —
                    // each shows its own linked fields (website: wantTo dropdown)
                    LokDropdownField(
                      label: 'i_want_to'.tr,
                      hint: 'choose'.tr,
                      icon: Icons.local_shipping_outlined,
                      required: true,
                      options: const [_sendLabel, _buyLabel],
                      value: _wantTo,
                      onChanged: (v) => setState(() {
                        _wantTo = v;
                        // a security deposit only applies to "deliver ready items"
                        if (_isBuyAndDeliver) _securityDeposit = false;
                      }),
                    ),
                    SizedBox(height: 14.h),
                    // profit sits beside the value field — the item value for a
                    // buy, the (grayed until required) deposit amount for a send
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: LokTextField(
                            label: 'traveler_profit'.tr,
                            hint: 'e_g_50'.tr,
                            icon: Icons.payments_outlined,
                            required: true,
                            keyboardType: TextInputType.number,
                            controller: _cost,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: LokTextField(
                            label: _isBuyAndDeliver
                                ? 'Item value'
                                : 'Security deposit amount',
                            hint: _isBuyAndDeliver ? 'item worth' : 'held, not charged',
                            icon: Icons.sell_outlined,
                            required: _isStripe && (_isBuyAndDeliver || _securityDeposit),
                            // send: stays grayed until a deposit is required
                            readOnly: !_isBuyAndDeliver && !_securityDeposit,
                            keyboardType: TextInputType.number,
                            controller: _itemValue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    // live FX estimate for the amount just entered
                    CurrencyConverter(amount: _cost),
                    // send + card: offer the deposit hold, with the same wording
                    // the website shows under the toggle
                    if (!_isBuyAndDeliver && _isStripe) ...[
                      SizedBox(height: 12.h),
                      LokCheckbox(
                        label: 'require_a_security_deposit_from_the_traveler'.tr,
                        value: _securityDeposit,
                        onChanged: (v) => setState(() {
                          _securityDeposit = v;
                          if (!v) _itemValue.clear();
                        }),
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 34.w, top: 4.h, right: 4.w),
                        child: Text(
                          'A temporary hold is placed on the traveler’s card for the '
                          'item’s value to protect against loss or damage. It is released '
                          'after successful delivery — they are never charged unless a '
                          'dispute is raised.',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: cs.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 14.h),
                    LokTextField(
                      label: 'weight_kg'.tr,
                      hint: 'e_g_2'.tr,
                      icon: Icons.scale_outlined,
                      required: true,
                      keyboardType: TextInputType.number,
                      controller: _weight,
                    ),
                    // item name + link identify the thing to buy — only a
                    // buy-and-deliver deal needs them (website: BUY-only fields)
                    if (_isBuyAndDeliver) ...[
                      SizedBox(height: 14.h),
                      LokTextField(
                        label: 'item_name'.tr,
                        hint: 'what_to_buy'.tr,
                        icon: Icons.inventory_2_outlined,
                        required: true,
                        controller: _itemName,
                      ),
                      SizedBox(height: 14.h),
                      LokTextField(
                        label: 'item_link'.tr,
                        hint: 'store_product_page_url'.tr,
                        icon: Icons.link,
                        required: true,
                        keyboardType: TextInputType.url,
                        controller: _itemLink,
                      ),
                    ],
                    SizedBox(height: 14.h),
                    LokTextField(
                      label: 'item_description_optional'.tr,
                      hint: 'color_size_packaging'.tr,
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
                                    ? (_isBuyAndDeliver
                                        ? 'Add reference images (optional)'
                                        : 'Add item photos (optional)')
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
                      label: 'trip_date'.tr,
                      hint: 'when_it_travels'.tr,
                      required: true,
                      withTime: true,
                      value: _tripDate,
                      onChanged: (d) => setState(() => _tripDate = d),
                    ),
                    SizedBox(height: 14.h),
                    LokDateField(
                      label: 'arrival_date'.tr,
                      hint: 'when_it_lands'.tr,
                      required: true,
                      withTime: true,
                      value: _arrivalDate,
                      onChanged: (d) => setState(() => _arrivalDate = d),
                    ),
                    SizedBox(height: 14.h),
                    LokTextField(
                      label: 'receiver_name'.tr,
                      hint: 'who_picks_it_up'.tr,
                      icon: Icons.person_outline,
                      required: true,
                      controller: _receiverName,
                    ),
                    SizedBox(height: 14.h),
                    LokDropdownField(
                      label: 'receiver_country'.tr,
                      hint: 'receiver_country_2'.tr,
                      icon: Icons.public,
                      required: true,
                      options: _countryNames,
                      searchable: true,
                      value: _receiverCountry,
                      onChanged: _onReceiverCountry,
                    ),
                    SizedBox(height: 14.h),
                    LokTextField(
                      label: 'receiver_phone'.tr,
                      hint: '+216...',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      required: true,
                      controller: _receiverPhone,
                    ),
                    SizedBox(height: 14.h),
                    LokDropdownField(
                      label: 'payment_method'.tr,
                      hint: 'payment_method_2'.tr,
                      icon: Icons.credit_card,
                      options: const ['Pay Online', 'Cash On Delivery'],
                      value: _payment,
                      onChanged: (v) => setState(() {
                        _payment = v;
                        // a security deposit is a card hold — impossible on cash
                        if (!_isStripe) _securityDeposit = false;
                      }),
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
                          : Text('confirm_continue'.tr),
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
      // tap to open full screen and pinch-zoom, same as the live chat
      return GestureDetector(
        onTap: () => ImageViewerPage.open(context, url, title: name),
        child: ClipRRect(
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
        ),
      );
    }
    // the url's last segment is "stream" — show the real filename when we have it
    final label = (name != null && name!.isNotEmpty)
        ? name!
        : url.split('/').last.split('?').first;
    // videos and documents can't be zoomed, but they still open
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: _fileChip(fg, label),
    );
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
              child: Text('click_here'.tr, style: TextStyle(fontSize: 12.sp)),
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
