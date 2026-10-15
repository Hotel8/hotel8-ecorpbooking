// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:ECorpBooking
// SPDX-License-Identifier: Apache-2.0

/// My Trips (Traveler).
///
/// Upcoming and past bookings, booking details (dates, property, rate,
/// payment method, status), modify/cancel (subject to corporate rate policy),
/// and add to calendar.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';

class MyTripsPage extends StatefulWidget {
  const MyTripsPage({
    super.key,
    required this.client,
    required this.company,
    this.travelerId,
  });

  final BffClient client;
  final Company company;
  final String? travelerId;

  @override
  State<MyTripsPage> createState() => _MyTripsPageState();
}

class _MyTripsPageState extends State<MyTripsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<List<CorporateBooking>> _upcomingFuture;
  late Future<List<CorporateBooking>> _pastFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _upcomingFuture = _load(upcoming: true);
    _pastFuture = _load(upcoming: false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<CorporateBooking>> _load({required bool upcoming}) async {
    final list = await widget.client.getBookings(
      companyId: widget.company.id,
      travelerId: widget.travelerId,
      upcoming: upcoming,
    );
    return list;
  }

  Future<void> _refresh() async {
    setState(() {
      _upcomingFuture = _load(upcoming: true);
      _pastFuture = _load(upcoming: false);
    });
    await Future.wait([_upcomingFuture, _pastFuture]);
  }

  Future<void> _cancelBooking(CorporateBooking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking?'),
        content: Text(
          'Cancel reservation ${booking.confirmationNumber}? '
          'This action may be subject to cancellation fees per corporate rate policy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.client.cancelBooking(widget.company.id, booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Booking cancelled.')));
        _refresh();
      }
    } on BffException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cancel failed: ${e.message}')));
      }
    }
  }

  void _showModifyOptions(CorporateBooking booking) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_calendar),
              title: const Text('Modify Dates'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Date modification — contact your travel manager',
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Change Traveler'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Traveler change — contact your travel manager',
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('View Booking Details'),
              onTap: () {
                Navigator.pop(ctx);
                _showDetails(booking);
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('Add to Calendar'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Added: ${DateFormat('MMM d').format(booking.arrivalDate)} — ${booking.propertyName}',
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.cancel,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Cancel Booking',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _cancelBooking(booking);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDetails(CorporateBooking booking) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BookingDetailSheet(booking: booking),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTab(_upcomingFuture, isUpcoming: true),
          _buildTab(_pastFuture, isUpcoming: false),
        ],
      ),
    );
  }

  Widget _buildTab(
    Future<List<CorporateBooking>> future, {
    required bool isUpcoming,
  }) {
    return FutureBuilder<List<CorporateBooking>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final msg = snapshot.error is BffException
              ? (snapshot.error as BffException).message
              : snapshot.error.toString();
          return _ErrorView(message: msg, onRetry: _refresh);
        }
        final list = snapshot.data ?? const [];
        if (list.isEmpty) {
          return _EmptyTrips(isUpcoming: isUpcoming, onRefresh: _refresh);
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _BookingCard(
              booking: list[i],
              isUpcoming: isUpcoming,
              onModify: () => _showModifyOptions(list[i]),
              onCancel: () => _cancelBooking(list[i]),
              onTap: () => _showDetails(list[i]),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Booking card
// ═══════════════════════════════════════════════════════════════════════════

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.isUpcoming,
    required this.onModify,
    required this.onCancel,
    required this.onTap,
  });

  final CorporateBooking booking;
  final bool isUpcoming;
  final VoidCallback onModify;
  final VoidCallback onCancel;
  final VoidCallback onTap;

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
    final fmt = NumberFormat.currency(
      name: booking.currencyCode,
      symbol: _symbolFor(booking.currencyCode),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                          booking.propertyName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${DateFormat('MMM d').format(booking.arrivalDate)} — ${DateFormat('MMM d').format(booking.departureDate)} · ${booking.numberOfNights} night${booking.numberOfNights != 1 ? "s" : ""}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(status: booking.status),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (booking.roomTypeName.isNotEmpty)
                    _InfoChip(icon: Icons.bed, text: booking.roomTypeName),
                  _InfoChip(
                    icon: Icons.location_on_outlined,
                    text: booking.propertyCity,
                  ),
                  _InfoChip(
                    icon: Icons.credit_card,
                    text: booking.paymentMethod.label,
                  ),
                  if (!booking.policyCompliant)
                    _InfoChip(
                      icon: Icons.warning_amber,
                      text: 'Out of Policy',
                      color: theme.colorScheme.error,
                    ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (booking.publicRateAmount > booking.rateAmount)
                        Text(
                          fmt.format(booking.publicRateAmount),
                          style: theme.textTheme.bodySmall?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      Text(
                        fmt.format(booking.rateAmount),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (booking.savings > 0)
                        Text(
                          'Save ${fmt.format(booking.savings)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  if (isUpcoming && booking.status.isUpcoming)
                    Row(
                      children: [
                        TextButton(
                          onPressed: onModify,
                          child: const Text('Modify'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: onCancel,
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                          ),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Status chip
// ═══════════════════════════════════════════════════════════════════════════

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final CorporateBookingStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color bg;
    Color fg;
    switch (status) {
      case CorporateBookingStatus.confirmed:
      case CorporateBookingStatus.pending:
        bg = theme.colorScheme.tertiaryContainer;
        fg = theme.colorScheme.onTertiaryContainer;
        break;
      case CorporateBookingStatus.checkedIn:
      case CorporateBookingStatus.checkedOut:
        bg = theme.colorScheme.primaryContainer;
        fg = theme.colorScheme.onPrimaryContainer;
        break;
      case CorporateBookingStatus.cancelled:
      case CorporateBookingStatus.noShow:
        bg = theme.colorScheme.errorContainer;
        fg = theme.colorScheme.onErrorContainer;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Booking detail sheet
// ═══════════════════════════════════════════════════════════════════════════

class _BookingDetailSheet extends StatelessWidget {
  const _BookingDetailSheet({required this.booking});
  final CorporateBooking booking;

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
    final fmt = NumberFormat.currency(
      name: booking.currencyCode,
      symbol: _symbolFor(booking.currencyCode),
    );
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
            Text('Booking Details', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            _DetailRow(
              label: 'Confirmation',
              value: booking.confirmationNumber,
            ),
            _DetailRow(label: 'Status', value: booking.status.label),
            _DetailRow(label: 'Property', value: booking.propertyName),
            _DetailRow(label: 'City', value: booking.propertyCity),
            _DetailRow(
              label: 'Dates',
              value:
                  '${DateFormat('MMM d, y').format(booking.arrivalDate)} — ${DateFormat('MMM d, y').format(booking.departureDate)}',
            ),
            _DetailRow(label: 'Nights', value: '${booking.numberOfNights}'),
            _DetailRow(label: 'Guests', value: '${booking.numberOfGuests}'),
            _DetailRow(label: 'Rooms', value: '${booking.numberOfRooms}'),
            if (booking.roomTypeName.isNotEmpty)
              _DetailRow(label: 'Room Type', value: booking.roomTypeName),
            if (booking.ratePlanName.isNotEmpty)
              _DetailRow(label: 'Rate Plan', value: booking.ratePlanName),
            _DetailRow(label: 'Traveler', value: booking.travelerName),
            _DetailRow(label: 'Payment', value: booking.paymentMethod.label),
            if (booking.poNumber != null)
              _DetailRow(label: 'PO Number', value: booking.poNumber!),
            if (booking.projectCode != null)
              _DetailRow(label: 'Project Code', value: booking.projectCode!),
            if (booking.costCenter != null)
              _DetailRow(label: 'Cost Center', value: booking.costCenter!),
            if (booking.purposeOfTravel != null)
              _DetailRow(label: 'Purpose', value: booking.purposeOfTravel!),
            const Divider(height: 24),
            _DetailRow(
              label: 'Corporate Rate',
              value: fmt.format(booking.rateAmount),
            ),
            if (booking.publicRateAmount > booking.rateAmount)
              _DetailRow(
                label: 'Public Rate',
                value: fmt.format(booking.publicRateAmount),
                strikethrough: true,
              ),
            if (booking.savings > 0)
              _DetailRow(
                label: 'Savings',
                value: fmt.format(booking.savings),
                highlight: true,
              ),
            if (!booking.policyCompliant)
              _DetailRow(
                label: 'Policy',
                value: booking.policyViolationReason ?? 'Out of policy',
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.strikethrough = false,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool strikethrough;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              decoration: strikethrough ? TextDecoration.lineThrough : null,
              color: highlight ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Error / empty
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
            const Text('Unable to load bookings'),
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

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips({required this.isUpcoming, required this.onRefresh});
  final bool isUpcoming;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(
          isUpcoming ? Icons.event_available : Icons.history,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 16),
        Text(
          isUpcoming ? 'No upcoming trips' : 'No past trips',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          isUpcoming
              ? 'Search and book your next business trip at corporate rates.'
              : 'Your booking history will appear here.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
