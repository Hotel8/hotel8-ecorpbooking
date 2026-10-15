// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:ECorpBooking
// SPDX-License-Identifier: Apache-2.0

/// Corporate Dashboard.
///
/// Welcome message with company name, quick search (destination, dates,
/// travelers), upcoming bookings list, company announcements / travel
/// policies, and quick links: Book Now, My Travelers, Reports.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';
import 'corporate_search_page.dart';
import 'my_trips_page.dart';
import 'traveler_management_page.dart';

class CorporateDashboardPage extends StatefulWidget {
  const CorporateDashboardPage({
    super.key,
    required this.client,
    required this.company,
  });

  final BffClient client;
  final Company company;

  @override
  State<CorporateDashboardPage> createState() => _CorporateDashboardPageState();
}

class _CorporateDashboardPageState extends State<CorporateDashboardPage> {
  DateTime? _checkIn;
  DateTime? _checkOut;
  final _destinationController = TextEditingController();
  int _travelers = 1;
  late Future<List<CorporateBooking>> _upcomingFuture;
  late Future<List<Announcement>> _announcementsFuture;

  @override
  void initState() {
    super.initState();
    _upcomingFuture = widget.client.getBookings(
      companyId: widget.company.id,
      upcoming: true,
    );
    _announcementsFuture = widget.client.getAnnouncements(widget.company.id);
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _pickCheckIn() async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: today.add(const Duration(days: 1)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date == null) return;
    setState(() {
      _checkIn = date;
      if (_checkOut == null ||
          _checkOut!.isBefore(date.add(const Duration(days: 1)))) {
        _checkOut = date.add(const Duration(days: 1));
      }
    });
  }

  Future<void> _pickCheckOut() async {
    final first =
        _checkIn?.add(const Duration(days: 1)) ??
        DateTime.now().add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: first,
      firstDate: first,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    setState(() => _checkOut = date);
  }

  void _doSearch() {
    if (_checkIn == null || _checkOut == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select check-in and check-out dates.'),
        ),
      );
      return;
    }
    final request = CorporateSearchRequest(
      destination: _destinationController.text.trim().isEmpty
          ? null
          : _destinationController.text.trim(),
      arrivalDate: _checkIn!,
      departureDate: _checkOut!,
      numberOfGuests: _travelers,
      companyCode: widget.company.companyCode,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CorporateSearchPage(
          client: widget.client,
          company: widget.company,
          request: request,
        ),
      ),
    );
  }

  void _openTrips() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MyTripsPage(client: widget.client, company: widget.company),
      ),
    );
  }

  void _openTravelers() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TravelerManagementPage(
          client: widget.client,
          company: widget.company,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _upcomingFuture = widget.client.getBookings(
              companyId: widget.company.id,
              upcoming: true,
            );
            _announcementsFuture = widget.client.getAnnouncements(
              widget.company.id,
            );
          });
          await Future.wait([_upcomingFuture, _announcementsFuture]);
        },
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.business_center,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                              Text(
                                widget.company.companyName,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Book your next business trip at negotiated corporate rates',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Quick search ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _destinationController,
                          decoration: const InputDecoration(
                            labelText: 'Destination or Hotel',
                            prefixIcon: Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _DateField(
                                label: 'Check-in',
                                value: _checkIn == null
                                    ? 'Add date'
                                    : DateFormat('MMM d').format(_checkIn!),
                                onTap: _pickCheckIn,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DateField(
                                label: 'Check-out',
                                value: _checkOut == null
                                    ? 'Add date'
                                    : DateFormat('MMM d').format(_checkOut!),
                                onTap: _pickCheckOut,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.people_outline, size: 20),
                            const SizedBox(width: 8),
                            const Text('Travelers'),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                size: 20,
                              ),
                              onPressed: _travelers > 1
                                  ? () => setState(() => _travelers--)
                                  : null,
                              visualDensity: VisualDensity.compact,
                            ),
                            Text(
                              '$_travelers',
                              style: theme.textTheme.titleMedium,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 20,
                              ),
                              onPressed: _travelers < 20
                                  ? () => setState(() => _travelers++)
                                  : null,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _doSearch,
                            icon: const Icon(Icons.search),
                            label: const Text('Search Corporate Rates'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Quick links ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickLink(
                        icon: Icons.flight_takeoff,
                        label: 'My Trips',
                        onTap: _openTrips,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickLink(
                        icon: Icons.group,
                        label: 'Travelers',
                        onTap: _openTravelers,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Upcoming bookings ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'Upcoming Bookings',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _openTrips,
                      child: const Text('View all'),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: FutureBuilder<List<CorporateBooking>>(
                future: _upcomingFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    final msg = snapshot.error is BffException
                        ? (snapshot.error as BffException).message
                        : snapshot.error.toString();
                    return _ErrorCard(
                      message: msg,
                      onRetry: () {
                        setState(
                          () => _upcomingFuture = widget.client.getBookings(
                            companyId: widget.company.id,
                            upcoming: true,
                          ),
                        );
                      },
                    );
                  }
                  final list = snapshot.data ?? const [];
                  if (list.isEmpty) {
                    return const _EmptyCard(
                      icon: Icons.event_available,
                      message: 'No upcoming bookings. Search to book your next trip.',
                    );
                  }
                  return Column(
                    children: list
                        .take(3)
                        .map((b) => _BookingMiniCard(booking: b))
                        .toList(),
                  );
                },
              ),
            ),

            // ── Announcements ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  'Company Announcements',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: FutureBuilder<List<Announcement>>(
                future: _announcementsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    final list = _mockAnnouncements();
                    return _AnnouncementList(announcements: list);
                  }
                  final list = snapshot.data ?? const [];
                  if (list.isEmpty) {
                    return const _EmptyCard(
                      icon: Icons.campaign_outlined,
                      message: 'No announcements at this time.',
                    );
                  }
                  return _AnnouncementList(announcements: list);
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  List<Announcement> _mockAnnouncements() {
    final now = DateTime.now();
    return [
      Announcement(
        id: '1',
        title: 'New Negotiated Rates Available',
        body: 'We have secured new corporate rates for the downtown properties effective this quarter. Enjoy up to 25% savings.',
        publishedAt: now.subtract(const Duration(days: 2)),
        category: 'Rates',
      ),
      Announcement(
        id: '2',
        title: 'Travel Policy Update',
        body: 'All bookings must be made at least 7 days in advance. Same-day bookings require manager approval.',
        publishedAt: now.subtract(const Duration(days: 7)),
        category: 'Policy',
      ),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Widgets
// ═══════════════════════════════════════════════════════════════════════════

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today, size: 18),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: Text(value, style: Theme.of(context).textTheme.titleSmall),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingMiniCard extends StatelessWidget {
  const _BookingMiniCard({required this.booking});
  final CorporateBooking booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.hotel, color: theme.colorScheme.onPrimaryContainer),
        ),
        title: Text(
          booking.propertyName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${DateFormat('MMM d').format(booking.arrivalDate)} — ${DateFormat('MMM d').format(booking.departureDate)} · ${booking.numberOfNights} nights',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              NumberFormat.currency(
                name: booking.currencyCode,
                symbol: _symbolFor(booking.currencyCode),
              ).format(booking.rateAmount),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(booking.status.label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementList extends StatelessWidget {
  const _AnnouncementList({required this.announcements});
  final List<Announcement> announcements;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: announcements
            .map((a) => _AnnouncementCard(announcement: a))
            .toList(),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement});
  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.campaign,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    announcement.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (announcement.category != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      announcement.category!,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(announcement.body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM d, y').format(announcement.publishedAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 40,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            icon,
            size: 40,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
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
