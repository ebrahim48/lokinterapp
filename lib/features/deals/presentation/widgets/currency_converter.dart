import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_palette.dart';
import '../../data/deals_repository.dart';

/// Shows what the entered amount is worth in another currency.
///
/// The rate comes from the backend (`/currency/convert`), which caches it, so
/// typing doesn't hammer the API — the lookup is debounced and only re-runs
/// when the amount or target currency actually changes. The result is labelled
/// an estimate because the payment provider may settle at a slightly
/// different rate.
class CurrencyConverter extends StatefulWidget {
  final TextEditingController amount;
  final String baseCurrency;

  const CurrencyConverter({
    super.key,
    required this.amount,
    this.baseCurrency = 'USD',
  });

  @override
  State<CurrencyConverter> createState() => _CurrencyConverterState();
}

class _CurrencyConverterState extends State<CurrencyConverter> {
  static const _currencies = ['EUR', 'TND', 'GBP', 'USD', 'AED', 'QAR', 'EGP'];

  final _repo = DealsRepository();
  Timer? _debounce;
  String _target = 'EUR';
  String? _result;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (_target == widget.baseCurrency) _target = 'USD';
    widget.amount.addListener(_schedule);
  }

  @override
  void dispose() {
    widget.amount.removeListener(_schedule);
    _debounce?.cancel();
    super.dispose();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _convert);
  }

  Future<void> _convert() async {
    final amount = double.tryParse(widget.amount.text.trim());
    if (amount == null || amount <= 0) {
      if (mounted) setState(() => _result = null);
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await _repo.convertCurrency(
        from: widget.baseCurrency,
        to: _target,
        amount: amount,
      );
      final converted = double.tryParse('${res['convertedAmount'] ?? ''}');
      if (!mounted) return;
      setState(() => _result =
          converted == null ? null : '${converted.toStringAsFixed(2)} $_target');
    } catch (_) {
      if (mounted) setState(() => _result = null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.currency_exchange, size: 16.sp, color: cs.onSurfaceVariant),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              _busy
                  ? 'calculating_fees'.tr
                  : _result == null
                      ? 'approx_in_another_currency'.tr
                      : '≈ $_result',
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: _result == null ? FontWeight.w400 : FontWeight.w700,
                color: _result == null ? cs.onSurfaceVariant : cs.onSurface,
              ),
            ),
          ),
          DropdownButton<String>(
            value: _target,
            underline: const SizedBox.shrink(),
            isDense: true,
            style: TextStyle(fontSize: 12.sp, color: AppPalette.primary),
            items: [
              for (final c in _currencies.where((c) => c != widget.baseCurrency))
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _target = v);
              _convert();
            },
          ),
        ],
      ),
    );
  }
}
