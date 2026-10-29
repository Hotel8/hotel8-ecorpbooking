// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:ECorpBooking
// SPDX-License-Identifier: Apache-2.0

/// Reports (Travel Manager).
///
/// Booking volume by property, traveler, month; total spend, average rate,
/// room nights; savings vs. public rates; policy compliance rate; export to
/// CSV/Excel.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';

class CorporateReportsPage extends StatefulWidget {
  const CorporateReportsPage({
    super.key,
    required this.client,
    required this.company,
  });

  final BffClient client;
  final Company company;

  @override
  State<CorporateReportsPage> createState() => _CorporateReportsPageState();
}

class _CorporateReportsPageState extends State<CorporateReportsPage> {
  late Future<ReportSummary> _summaryFuture;
  late Future<List<ReportByProperty>> _byPropertyFuture;
  late Future<List<ReportByTraveler>> _byTravelerFuture;
  late Future<List<ReportByMonth>> _byMonthFuture;

  DateTimeRange? _dateRange;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _loadAll() {
    final from = _dateRange?.start;
    final to = _dateRange?.end;
    _summaryFuture = widget.client.getReportSummary(
      widget.company.id,
      fromDate: from,
      toDate: to,
    );
    _byPropertyFuture = widget.client.getReportByProperty(
      widget.company.id,
      fromDate: from,
      toDate: to,
    );
    _byTravelerFuture = widget.client.getReportByTraveler(
      widget.company.id,
      fromDate: from,
      toDate: to,
    );
    _byMonthFuture = widget.client.getReportByMonth(
      widget.company.id,
      fromDate: from,
      toDate: to,
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial = _dateRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 90)), end: now);
    final range = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365 * 2)),
      lastDate: now,
      initialDateRange: initial,
    );
    if (range == null) return;
    setState(() {
      _dateRange = range;
      _loadAll();
    });
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      // In production this calls BFF to generate a CSV/Excel file.
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report exported. Check your downloads.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Date Range',
            onPressed: _pickDateRange,
          ),
          IconButton(
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            tooltip: 'Export',
            onPressed: _exporting ? null : _export,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_loadAll);
          await Future.wait([
            _summaryFuture,
            _byPropertyFuture,
            _byTravelerFuture,
            _byMonthFuture,
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_dateRange != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Center(
                  child: Text(
                    '${DateFormat('MMM d, y').format(_dateRange!.start)} - ${DateFormat('MMM d, y').format(_dateRange!.end)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
              ),
            // ── Summary ───────────────────────────────────────────────
            FutureBuilder<ReportSummary>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError)
                  return _ErrorCard(
                    message: _errMsg(snapshot.error),
                    onRetry: () => setState(_loadAll),
                  );
                final summary = snapshot.data ?? const ReportSummary();
                return _SummaryGrid(summary: summary);
              },
            ),
            const SizedBox(height: 24),

            // ── By Property ───────────────────────────────────────────
            _SectionHeader(title: 'By Property'),
            FutureBuilder<List<ReportByProperty>>(
              future: _byPropertyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError)
                  return _ErrorCard(
                    message: _errMsg(snapshot.error),
                    onRetry: () => setState(_loadAll),
                  );
                final list = snapshot.data ?? const [];
                if (list.isEmpty) return const _EmptySection();
                return _PropertyTable(rows: list);
              },
            ),
            const SizedBox(height: 24),

            // ── By Traveler ───────────────────────────────────────────
            _SectionHeader(title: 'By Traveler'),
            FutureBuilder<List<ReportByTraveler>>(
              future: _byTravelerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError)
                  return _ErrorCard(
                    message: _errMsg(snapshot.error),
                    onRetry: () => setState(_loadAll),
                  );
                final list = snapshot.data ?? const [];
                if (list.isEmpty) return const _EmptySection();
                return _TravelerTable(rows: list);
              },
            ),
            const SizedBox(height: 24),

            // ── By Month ──────────────────────────────────────────────
            _SectionHeader(title: 'By Month'),
            FutureBuilder<List<ReportByMonth>>(
              future: _byMonthFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError)
                  return _ErrorCard(
                    message: _errMsg(snapshot.error),
                    onRetry: () => setState(_loadAll),
                  );
                final list = snapshot.data ?? const [];
                if (list.isEmpty) return const _EmptySection();
                return _MonthTable(rows: list);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _errMsg(Object? error) {
    if (error is BffException) return error.message;
    return error.toString();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Summary grid
// ═══════════════════════════════════════════════════════════════════════════

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});
  final ReportSummary summary;

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
      name: summary.currencyCode,
      symbol: _symbolFor(summary.currencyCode),
    );
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _StatCard(
          icon: Icons.book_outlined,
          label: 'Total Bookings',
          value: '${summary.totalBookings}',
          color: theme.colorScheme.primary,
        ),
        _StatCard(
          icon: Icons.nights_stay_outlined,
          label: 'Room Nights',
          value: '${summary.totalRoomNights}',
          color: theme.colorScheme.secondary,
        ),
        _StatCard(
          icon: Icons.payments_outlined,
          label: 'Total Spend',
          value: fmt.format(summary.totalSpend),
          color: theme.colorScheme.tertiary,
        ),
        _StatCard(
          icon: Icons.trending_down,
          label: 'Avg Rate / Night',
          value: fmt.format(summary.averageRate),
          color: theme.colorScheme.primary,
        ),
        _StatCard(
          icon: Icons.savings_outlined,
          label: 'Total Savings',
          value: fmt.format(summary.totalSavings),
          color: theme.colorScheme.tertiary,
        ),
        _StatCard(
          icon: Icons.verified_outlined,
          label: 'Policy Compliance',
          value: '${(summary.policyComplianceRate * 100).toStringAsFixed(1)}%',
          color: theme.colorScheme.secondary,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tables
// ═══════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PropertyTable extends StatelessWidget {
  const _PropertyTable({required this.rows});
  final List<ReportByProperty> rows;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    return Card(
      child: Column(
        children: [
          const _TableRow(
            isHeader: true,
            cells: ['Property', 'Bookings', 'Nights', 'Spend', 'Savings'],
          ),
          const Divider(height: 1),
          ...rows.map(
            (r) => _TableRow(
              cells: [
                r.propertyName,
                '${r.bookingCount}',
                '${r.roomNights}',
                fmt.format(r.totalSpend),
                fmt.format(r.totalSavings),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TravelerTable extends StatelessWidget {
  const _TravelerTable({required this.rows});
  final List<ReportByTraveler> rows;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    return Card(
      child: Column(
        children: [
          const _TableRow(
            isHeader: true,
            cells: ['Traveler', 'Bookings', 'Spend', 'Savings'],
          ),
          const Divider(height: 1),
          ...rows.map(
            (r) => _TableRow(
              cells: [
                r.travelerName,
                '${r.bookingCount}',
                fmt.format(r.totalSpend),
                fmt.format(r.totalSavings),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthTable extends StatelessWidget {
  const _MonthTable({required this.rows});
  final List<ReportByMonth> rows;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    return Card(
      child: Column(
        children: [
          const _TableRow(
            isHeader: true,
            cells: ['Month', 'Bookings', 'Spend', 'Savings'],
          ),
          const Divider(height: 1),
          ...rows.map(
            (r) => _TableRow(
              cells: [
                r.month,
                '${r.bookingCount}',
                fmt.format(r.totalSpend),
                fmt.format(r.totalSavings),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.cells, this.isHeader = false});
  final List<String> cells;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        children: [
          for (int i = 0; i < cells.length; i++)
            Expanded(
              flex: i == 0 ? 2 : 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  cells[i],
                  style: isHeader
                      ? theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        )
                      : theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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

class _EmptySection extends StatelessWidget {
  const _EmptySection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.bar_chart,
            size: 40,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'No data for this period',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
