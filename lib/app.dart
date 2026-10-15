// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:ECorpBooking
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

import 'package:sentin8/sentin8.dart';

import 'bff_client.dart';
import 'models.dart';
import 'screens/corporate_dashboard_page.dart';
import 'screens/corporate_login_page.dart';
import 'screens/corporate_reports_page.dart';
import 'screens/corporate_search_page.dart';
import 'screens/my_trips_page.dart';
import 'screens/company_profile_page.dart';

class HcorpApp extends StatelessWidget {
  const HcorpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hcorp — Corporate Booking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HcorpRoot(),
    );
  }
}

/// Root widget — shows the login page until the company context is
/// resolved, then switches to the bottom-navigation shell.
class HcorpRoot extends StatefulWidget {
  const HcorpRoot({super.key});

  @override
  State<HcorpRoot> createState() => _HcorpRootState();
}

class _HcorpRootState extends State<HcorpRoot> {
  AppRuntimeContext? _runtimeContext;
  BffClient? _client;
  String? _bootstrapError;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      // Same-origin bootstrap — TLS injects the X-Sentin8-* host headers
      // the runtime context resolves from (ecorpbooking/DESIGN.md §2).
      final ctx = await fetchRuntimeContext(appBaseUrl: '');
      setState(() {
        _runtimeContext = ctx;
        _client = BffClient(
          baseUrl: ctx.bffBaseUrl,
          propertyId: ctx.environmentId,
        );
      });
    } catch (e) {
      setState(() => _bootstrapError = e.toString());
    }
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapError != null) {
      return Scaffold(
        body: Center(child: Text('eCorpBooking unavailable: $_bootstrapError')),
      );
    }
    final client = _client;
    if (client == null || _runtimeContext == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return CorporateLoginPage(client: client);
  }
}

/// Shell with a bottom navigation bar: Dashboard, Search, My Trips,
/// Reports, Profile. Shown after the corporate user has logged in.
class HcorpShell extends StatefulWidget {
  const HcorpShell({super.key, required this.client, required this.company});

  final BffClient client;
  final Company company;

  @override
  State<HcorpShell> createState() => _HcorpShellState();
}

class _HcorpShellState extends State<HcorpShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      CorporateDashboardPage(client: widget.client, company: widget.company),
      _SearchTab(client: widget.client, company: widget.company),
      MyTripsPage(client: widget.client, company: widget.company),
      CorporateReportsPage(client: widget.client, company: widget.company),
      CompanyProfilePage(client: widget.client, company: widget.company),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.flight_takeoff_outlined),
            selectedIcon: Icon(Icons.flight_takeoff),
            label: 'My Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.business_outlined),
            selectedIcon: Icon(Icons.business),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// The "Search" tab — a compact search form that pushes the corporate
/// search results page when the user taps "Search Corporate Rates".
class _SearchTab extends StatefulWidget {
  const _SearchTab({required this.client, required this.company});

  final BffClient client;
  final Company company;

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  DateTime? _checkIn;
  DateTime? _checkOut;
  final _destinationController = TextEditingController();
  int _travelers = 1;

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
    final first = _checkIn?.add(const Duration(days: 1)) ??
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      child: InkWell(
                        onTap: _pickCheckIn,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Check-in',
                            prefixIcon: Icon(Icons.calendar_today, size: 18),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          child: Text(
                            _checkIn == null
                                ? 'Add date'
                                : '${_checkIn!.day}/${_checkIn!.month}/${_checkIn!.year}',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _pickCheckOut,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Check-out',
                            prefixIcon: Icon(Icons.calendar_today, size: 18),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          child: Text(
                            _checkOut == null
                                ? 'Add date'
                                : '${_checkOut!.day}/${_checkOut!.month}/${_checkOut!.year}',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
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
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      onPressed: _travelers > 1
                          ? () => setState(() => _travelers--)
                          : null,
                      visualDensity: VisualDensity.compact,
                    ),
                    Text('$_travelers', style: theme.textTheme.titleMedium),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20),
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
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.business_center,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Company code ${widget.company.companyCode} auto-applied — only corporate negotiated rates will be shown.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
