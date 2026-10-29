// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:ECorpBooking
// SPDX-License-Identifier: Apache-2.0

/// Corporate Search & Book.
///
/// Similar to Hbook but with corporate-specific features:
/// - Only shows corporate negotiated rates (not public rates)
/// - Rate display: corporate rate, public rate (strikethrough), savings
/// - Company code auto-applied
/// - Policy enforcement: rate caps highlighted, out-of-policy bookings flagged
/// - Traveler selection: assign booking to self or another traveler
/// - Payment method: credit card, post-pay (PO number), bill-to-company
/// - Booking notes: project code, cost center, purpose of travel

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';

class CorporateSearchPage extends StatefulWidget {
  const CorporateSearchPage({
    super.key,
    required this.client,
    required this.company,
    required this.request,
  });

  final BffClient client;
  final Company company;
  final CorporateSearchRequest request;

  @override
  State<CorporateSearchPage> createState() => _CorporateSearchPageState();
}

class _CorporateSearchPageState extends State<CorporateSearchPage> {
  late Future<List<SearchResult>> _future;
  List<SearchResult>? _allResults;
  List<Traveler>? _travelers;
  String _selectedTravelerId = '';
  bool _policyOnly = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadTravelers();
  }

  Future<List<SearchResult>> _load() async {
    final results = await widget.client.searchCorporateAvailability(
      widget.request,
      companyId: widget.company.id,
    );
    _allResults = results;
    return results;
  }

  Future<void> _loadTravelers() async {
    try {
      final travelers = await widget.client.getTravelers(widget.company.id);
      if (mounted) {
        setState(() {
          _travelers = travelers;
          if (travelers.isNotEmpty) _selectedTravelerId = travelers.first.id;
        });
      }
    } catch (_) {
      // Non-fatal - booking defaults to self.
    }
  }

  List<SearchResult> get _filtered {
    var list = _allResults ?? [];
    if (_policyOnly) {
      list = list.where((r) => r.policyCompliant).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final nights = widget.request.departureDate
        .difference(widget.request.arrivalDate)
        .inDays;
    return Scaffold(
      appBar: AppBar(title: const Text('Corporate Search')),
      body: Column(
        children: [
          // ── Search summary bar ──────────────────────────────────────
          _SearchSummaryBar(request: widget.request, nights: nights),

          // ── Policy filter ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Policy-compliant only'),
                  selected: _policyOnly,
                  onSelected: (v) => setState(() => _policyOnly = v),
                ),
                const Spacer(),
                Text(
                  '${_allResults?.length ?? 0} corporate rates',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),

          // ── Results ──────────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _allResults = null;
                setState(() => _future = _load());
                await _future;
              },
              child: FutureBuilder<List<SearchResult>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    final msg = snapshot.error is BffException
                        ? (snapshot.error as BffException).message
                        : snapshot.error.toString();
                    return _ErrorView(
                      message: msg,
                      onRetry: () => setState(() => _future = _load()),
                    );
                  }
                  if (_allResults == null) return const SizedBox();
                  final list = _filtered;
                  if (list.isEmpty) {
                    return const _EmptyResults();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, i) => _RateCard(
                      result: list[i],
                      nights: nights,
                      onSelect: () => _openBookingSheet(list[i]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openBookingSheet(SearchResult result) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BookingSheet(
        client: widget.client,
        company: widget.company,
        result: result,
        request: widget.request,
        travelers: _travelers ?? const [],
        selectedTravelerId: _selectedTravelerId,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Search summary bar
// ═══════════════════════════════════════════════════════════════════════════

class _SearchSummaryBar extends StatelessWidget {
  const _SearchSummaryBar({required this.request, required this.nights});
  final CorporateSearchRequest request;
  final int nights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, size: 18),
          const SizedBox(width: 8),
          Text(
            '${DateFormat('MMM d').format(request.arrivalDate)} - ${DateFormat('MMM d').format(request.departureDate)}',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(width: 8),
          Text(
            '· $nights night${nights != 1 ? "s" : ""}',
            style: theme.textTheme.bodySmall,
          ),
          const Spacer(),
          const Icon(Icons.people_outline, size: 18),
          const SizedBox(width: 4),
          Text(
            '${request.numberOfGuests} traveler${request.numberOfGuests != 1 ? "s" : ""}',
            style: theme.textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Rate card
// ═══════════════════════════════════════════════════════════════════════════

class _RateCard extends StatelessWidget {
  const _RateCard({
    required this.result,
    required this.nights,
    required this.onSelect,
  });

  final SearchResult result;
  final int nights;
  final VoidCallback onSelect;

  String _symbolFor(String code) {
    switch (code) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return '$code ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = result.rate;
    final fmt = NumberFormat.currency(
      name: rate.currencyCode,
      symbol: _symbolFor(rate.currencyCode),
    );
    final totalCorporate = rate.corporateRate * nights;
    final totalPublic = rate.publicRate * nights;
    final outOfPolicy = !result.policyCompliant;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.hotel,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rate.propertyName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${rate.propertyCity} · ${rate.roomTypeName}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (outOfPolicy)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Out of Policy',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'In Policy',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (rate.ratePlanName.isNotEmpty)
              Text(
                rate.ratePlanName,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (rate.breakfastIncluded)
              Row(
                children: [
                  Icon(
                    Icons.free_breakfast,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text('Breakfast included', style: theme.textTheme.bodySmall),
                ],
              ),
            if (rate.cancellationPolicy != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.policy_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      rate.cancellationPolicy!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Public rate (strikethrough)
                    if (rate.publicRate > rate.corporateRate)
                      Text(
                        fmt.format(totalPublic),
                        style: theme.textTheme.bodySmall?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    // Corporate rate
                    Text(
                      fmt.format(totalCorporate),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      '${fmt.format(rate.corporateRate)}/night · $nights night${nights != 1 ? "s" : ""}',
                      style: theme.textTheme.bodySmall,
                    ),
                    // Savings
                    if (rate.savings > 0)
                      Text(
                        'Save ${fmt.format(rate.savings * nights)} (${rate.savingsPercent.toStringAsFixed(0)}%)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                FilledButton(
                  onPressed: onSelect,
                  child: const Text('Book Now'),
                ),
              ],
            ),
            if (outOfPolicy && result.policyViolationReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.policyViolationReason!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Booking bottom sheet
// ═══════════════════════════════════════════════════════════════════════════

class _BookingSheet extends StatefulWidget {
  const _BookingSheet({
    required this.client,
    required this.company,
    required this.result,
    required this.request,
    required this.travelers,
    required this.selectedTravelerId,
  });

  final BffClient client;
  final Company company;
  final SearchResult result;
  final CorporateSearchRequest request;
  final List<Traveler> travelers;
  final String selectedTravelerId;

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  late String _travelerId;
  PaymentMethod _paymentMethod = PaymentMethod.creditCard;
  final _poController = TextEditingController();
  final _projectController = TextEditingController();
  final _costCenterController = TextEditingController();
  final _purposeController = TextEditingController();
  final _notesController = TextEditingController();
  bool _submitting = false;

  /// Live credit approval surface (ecorpbooking/DESIGN.md §4 Credit methods):
  /// the company's POSTPAY/BILL_TO_COMPANY rows decide which credit methods
  /// the sheet may offer - the static company booleans are fallbacks when the
  /// surface is unreachable.
  List<CreditMethod> _creditMethods = const [];
  bool _creditLoaded = false;

  @override
  void initState() {
    super.initState();
    _travelerId = widget.selectedTravelerId;
    _loadCreditMethods();
  }

  Future<void> _loadCreditMethods() async {
    try {
      _creditMethods = await widget.client.getApprovedCreditMethods(
        widget.company.id,
      );
    } on BffException {
      // Live surface unreachable - fall back to the static company flags.
    }
    if (mounted) setState(() => _creditLoaded = true);
  }

  bool get _postPayApproved =>
      _creditMethods.any((m) => m.approval == 'POSTPAY') ||
      (!_creditLoaded && widget.company.postPayApproved);

  bool get _billToCompanyApproved =>
      _creditMethods.any((m) => m.approval == 'BILL_TO_COMPANY') ||
      (!_creditLoaded && widget.company.billToCompanyApproved);

  @override
  void dispose() {
    _poController.dispose();
    _projectController.dispose();
    _costCenterController.dispose();
    _purposeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _confirmBooking() async {
    if (_travelerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a traveler.')),
      );
      return;
    }
    if (_paymentMethod == PaymentMethod.postPay &&
        _poController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PO number is required for post-pay.')),
      );
      return;
    }
    if (_paymentMethod == PaymentMethod.billToCompany &&
        !_billToCompanyApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill-to-company is not approved for your account.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final booking = CorporateBookingCreate(
        arrivalDate: widget.request.arrivalDate,
        departureDate: widget.request.departureDate,
        numberOfRooms: widget.request.numberOfRooms,
        numberOfGuests: widget.request.numberOfGuests,
        propertyCode: widget.result.rate.propertyCode,
        roomTypeCode: widget.result.rate.roomTypeCode,
        ratePlanCode: widget.result.rate.ratePlanCode,
        travelerId: _travelerId,
        paymentMethod: _paymentMethod,
        poNumber: _poController.text.trim().isEmpty
            ? null
            : _poController.text.trim(),
        projectCode: _projectController.text.trim().isEmpty
            ? null
            : _projectController.text.trim(),
        costCenter: _costCenterController.text.trim().isEmpty
            ? null
            : _costCenterController.text.trim(),
        purposeOfTravel: _purposeController.text.trim().isEmpty
            ? null
            : _purposeController.text.trim(),
        specialRequests: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      final result = await widget.client.createCorporateBooking(
        widget.company.id,
        booking,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking confirmed: ${result.confirmationNumber}'),
          ),
        );
      }
    } on BffException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Booking failed: ${e.message}')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = widget.result.rate;
    final nights = widget.request.departureDate
        .difference(widget.request.arrivalDate)
        .inDays;
    final fmt = NumberFormat.currency(
      name: rate.currencyCode,
      symbol: _symbolFor(rate.currencyCode),
    );
    final total = rate.corporateRate * nights;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Text('Confirm Booking', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '${rate.propertyName} · ${rate.roomTypeName}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${DateFormat('MMM d').format(widget.request.arrivalDate)} - ${DateFormat('MMM d').format(widget.request.departureDate)}',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        '$nights night${nights != 1 ? "s" : ""} · ${widget.request.numberOfGuests} traveler${widget.request.numberOfGuests != 1 ? "s" : ""}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Text(
                    fmt.format(total),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Traveler selection
            Text(
              'Traveler',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _travelerId.isEmpty ? null : _travelerId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: widget.travelers
                  .map(
                    (t) =>
                        DropdownMenuItem(value: t.id, child: Text(t.fullName)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _travelerId = v ?? ''),
            ),
            const SizedBox(height: 16),

            // Payment method
            Text(
              'Payment Method',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Credit Card'),
                  selected: _paymentMethod == PaymentMethod.creditCard,
                  onSelected: (_) =>
                      setState(() => _paymentMethod = PaymentMethod.creditCard),
                ),
                if (_postPayApproved)
                  ChoiceChip(
                    label: const Text('Post-Pay (PO)'),
                    selected: _paymentMethod == PaymentMethod.postPay,
                    onSelected: (_) =>
                        setState(() => _paymentMethod = PaymentMethod.postPay),
                  ),
                if (_billToCompanyApproved)
                  ChoiceChip(
                    label: const Text('Bill to Company'),
                    selected: _paymentMethod == PaymentMethod.billToCompany,
                    onSelected: (_) => setState(
                      () => _paymentMethod = PaymentMethod.billToCompany,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // PO number (if post-pay)
            if (_paymentMethod == PaymentMethod.postPay) ...[
              TextField(
                controller: _poController,
                decoration: const InputDecoration(
                  labelText: 'PO Number *',
                  prefixIcon: Icon(Icons.receipt_long),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Project code / cost center / purpose
            TextField(
              controller: _projectController,
              decoration: const InputDecoration(
                labelText: 'Project Code',
                prefixIcon: Icon(Icons.work_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _costCenterController,
              decoration: const InputDecoration(
                labelText: 'Cost Center',
                prefixIcon: Icon(Icons.account_balance_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _purposeController,
              decoration: const InputDecoration(
                labelText: 'Purpose of Travel',
                prefixIcon: Icon(Icons.flight_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Special Requests (optional)',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Policy warning
            if (!widget.result.policyCompliant)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.result.policyViolationReason ??
                            'This booking is out of policy and may require manager approval.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            if (!widget.result.policyCompliant) const SizedBox(height: 16),

            // Confirm button
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _submitting ? null : _confirmBooking,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('Confirm Booking · ${fmt.format(total)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Error / empty views
// ═══════════════════════════════════════════════════════════════════════════

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            const Text('Unable to load corporate rates'),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.search_off,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 16),
        Text(
          'No corporate rates available',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Try adjusting your dates or destination. Contact your travel manager if you need additional properties.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

String _symbolFor(String code) {
  switch (code) {
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    default:
      return '$code ';
  }
}
