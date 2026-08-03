import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/notify.dart';
import '../../data/deals_repository.dart';

/// Converts a familiar currency INTO the one the deal settles in.
///
/// The sender thinks in their own currency, so they type an amount here, pick
/// that currency, and the converted total can be dropped straight into the
/// traveler-profit field — no mental arithmetic, and the number that reaches
/// the API is always in the settlement currency.
///
/// The rate comes from the backend (`/currency/convert`), which caches it, so
/// typing doesn't hammer the API. It's labelled an estimate because the payment
/// provider may settle at a slightly different rate.
class CurrencyConverter extends StatefulWidget {
  /// The traveler-profit field, in [settlementCurrency]. Filled by "Use".
  final TextEditingController amount;
  final String settlementCurrency;

  const CurrencyConverter({
    super.key,
    required this.amount,
    this.settlementCurrency = 'USD',
  });

  @override
  State<CurrencyConverter> createState() => _CurrencyConverterState();
}

class _CurrencyConverterState extends State<CurrencyConverter> {
  static const _currencies = ['EUR', 'TND', 'GBP', 'USD', 'AED', 'QAR', 'EGP'];

  final _repo = DealsRepository();
  final _input = TextEditingController();
  Timer? _debounce;
  String _from = 'EUR';
  double? _converted;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (_from == widget.settlementCurrency) _from = 'TND';
    _input.addListener(_schedule);
  }

  @override
  void dispose() {
    _input.removeListener(_schedule);
    _input.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _convert);
  }

  Future<void> _convert() async {
    final amount = double.tryParse(_input.text.trim());
    if (amount == null || amount <= 0) {
      if (mounted) setState(() => _converted = null);
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await _repo.convertCurrency(
        from: _from,
        to: widget.settlementCurrency,
        amount: amount,
      );
      if (!mounted) return;
      setState(() =>
          _converted = double.tryParse('${res['convertedAmount'] ?? ''}'));
    } catch (_) {
      if (mounted) setState(() => _converted = null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // drop the converted figure into the profit field
  void _use() {
    final v = _converted;
    if (v == null) return;
    widget.amount.text = v.toStringAsFixed(2);
    FocusScope.of(context).unfocus();
    toast('profit_set_from_conversion'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ready = _converted != null;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.currency_exchange, size: 15.sp, color: cs.onSurfaceVariant),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'convert_to_settlement'
                      .trParams({'currency': widget.settlementCurrency}),
                  style: TextStyle(fontSize: 11.5.sp, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              // amount in the currency the sender thinks in
              Expanded(
                child: TextField(
                  controller: _input,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'amount'.tr,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                  ),
                  style: TextStyle(fontSize: 13.sp),
                ),
              ),
              SizedBox(width: 8.w),
              DropdownButton<String>(
                value: _from,
                underline: const SizedBox.shrink(),
                isDense: true,
                style: TextStyle(fontSize: 12.sp, color: AppPalette.primary),
                items: [
                  for (final c
                      in _currencies.where((c) => c != widget.settlementCurrency))
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _from = v);
                  _convert();
                },
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  _busy
                      ? 'calculating_fees'.tr
                      : ready
                          ? '≈ ${_converted!.toStringAsFixed(2)} ${widget.settlementCurrency}'
                          : 'estimate_only'.tr,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: ready ? FontWeight.w700 : FontWeight.w400,
                    color: ready ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: ready ? _use : null,
                child: Text('use'.tr, style: TextStyle(fontSize: 12.sp)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
