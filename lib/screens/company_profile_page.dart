// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:ECorpBooking
// SPDX-License-Identifier: Apache-2.0

/// Company Profile.
///
/// Company name, address, tax ID, billing address, default payment method,
/// travel policy settings, approved properties, and department/cost center
/// list.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';

class CompanyProfilePage extends StatefulWidget {
  const CompanyProfilePage({
    super.key,
    required this.client,
    required this.company,
  });

  final BffClient client;
  final Company company;

  @override
  State<CompanyProfilePage> createState() => _CompanyProfilePageState();
}

class _CompanyProfilePageState extends State<CompanyProfilePage> {
  late Future<CompanyProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.client.getCompanyProfile(widget.company.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _profileFuture = widget.client.getCompanyProfile(widget.company.id);
    });
    await _profileFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company Profile')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<CompanyProfile>(
          future: _profileFuture,
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
            final profile = snapshot.data;
            if (profile == null) return const SizedBox();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Company info ───────────────────────────────────────
                _SectionCard(
                  title: 'Company Information',
                  icon: Icons.business,
                  children: [
                    _InfoRow(label: 'Company Name', value: profile.companyName),
                    _InfoRow(label: 'Company Code', value: profile.companyCode),
                    if (widget.company.industry != null)
                      _InfoRow(
                        label: 'Industry',
                        value: widget.company.industry!,
                      ),
                    if (profile.taxId != null)
                      _InfoRow(label: 'Tax ID', value: profile.taxId!),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Billing address ────────────────────────────────────
                _SectionCard(
                  title: 'Billing Address',
                  icon: Icons.location_on_outlined,
                  children: [
                    if (profile.billingAddress.addressLine1 != null)
                      _InfoRow(
                        label: 'Address',
                        value: profile.billingAddress.addressLine1!,
                      ),
                    if (profile.billingAddress.addressLine2 != null)
                      _InfoRow(
                        label: 'Address 2',
                        value: profile.billingAddress.addressLine2!,
                      ),
                    _InfoRow(
                      label: 'City',
                      value:
                          [
                                profile.billingAddress.city,
                                profile.billingAddress.state,
                              ]
                              .whereType<String>()
                              .where((s) => s.isNotEmpty)
                              .join(', '),
                    ),
                    _InfoRow(
                      label: 'Postal / Country',
                      value:
                          [
                                profile.billingAddress.postalCode,
                                profile.billingAddress.country,
                              ]
                              .whereType<String>()
                              .where((s) => s.isNotEmpty)
                              .join(', '),
                    ),
                    if (profile.billingContactName != null)
                      _InfoRow(
                        label: 'Contact',
                        value: profile.billingContactName!,
                      ),
                    if (profile.billingContactEmail != null)
                      _InfoRow(
                        label: 'Email',
                        value: profile.billingContactEmail!,
                      ),
                    if (profile.billingContactPhone != null)
                      _InfoRow(
                        label: 'Phone',
                        value: profile.billingContactPhone!,
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Payment settings ───────────────────────────────────
                _SectionCard(
                  title: 'Payment Settings',
                  icon: Icons.payments_outlined,
                  children: [
                    _InfoRow(
                      label: 'Default Payment',
                      value: profile.defaultPaymentMethod.label,
                    ),
                    if (profile.paymentTerms != null)
                      _InfoRow(
                        label: 'Payment Terms',
                        value: profile.paymentTerms!,
                      ),
                    _InfoRow(
                      label: 'Post-Pay Approved',
                      value: widget.company.postPayApproved ? 'Yes' : 'No',
                    ),
                    _InfoRow(
                      label: 'Bill-to-Company',
                      value: widget.company.billToCompanyApproved
                          ? 'Yes'
                          : 'No',
                    ),
                    if (widget.company.creditLimit != null)
                      _InfoRow(
                        label: 'Credit Limit',
                        value: NumberFormat.currency(
                          name: profile.currencyCode,
                          symbol: _symbolFor(profile.currencyCode),
                        ).format(widget.company.creditLimit!),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Travel policies ────────────────────────────────────
                _SectionCard(
                  title: 'Travel Policies',
                  icon: Icons.policy_outlined,
                  children: profile.travelPolicies.isEmpty
                      ? [const Text('No travel policies configured.')]
                      : profile.travelPolicies
                            .map((p) => _PolicyTile(policy: p))
                            .toList(),
                ),
                const SizedBox(height: 16),

                // ── Approved properties ────────────────────────────────
                _SectionCard(
                  title: 'Approved Properties',
                  icon: Icons.hotel,
                  children: profile.approvedProperties.isEmpty
                      ? [
                          const Text(
                            'No approved property restrictions — all properties allowed.',
                          ),
                        ]
                      : [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: profile.approvedProperties
                                .map((p) => _PropertyChip(property: p))
                                .toList(),
                          ),
                        ],
                ),
                const SizedBox(height: 16),

                // ── Cost centers ───────────────────────────────────────
                _SectionCard(
                  title: 'Departments & Cost Centers',
                  icon: Icons.account_balance_outlined,
                  children: profile.costCenters.isEmpty
                      ? [const Text('No cost centers configured.')]
                      : profile.costCenters
                            .map((c) => _CostCenterTile(costCenter: c))
                            .toList(),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Widgets
// ═══════════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (value.trim().isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyTile extends StatelessWidget {
  const _PolicyTile({required this.policy});
  final TravelPolicy policy;

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
      name: policy.currencyCode,
      symbol: _symbolFor(policy.currencyCode),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                policy.policyName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (policy.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                )
              else
                Text('(inactive)', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              if (policy.maxRatePerNight > 0)
                _PolicyBadge(
                  label: 'Max rate',
                  value: '${fmt.format(policy.maxRatePerNight)}/night',
                ),
              if (policy.maxAdvanceDays > 0)
                _PolicyBadge(
                  label: 'Max advance',
                  value: '${policy.maxAdvanceDays} days',
                ),
              if (policy.minLeadDays > 0)
                _PolicyBadge(
                  label: 'Min lead',
                  value: '${policy.minLeadDays} days',
                ),
              _PolicyBadge(
                label: 'Weekend',
                value: policy.allowWeekendBooking ? 'Allowed' : 'Restricted',
              ),
              _PolicyBadge(
                label: 'Approval',
                value: policy.requireApprovalForOutPolicy
                    ? 'Required'
                    : 'Not required',
              ),
            ],
          ),
          if (policy.approvedCities.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Approved cities: ${policy.approvedCities.join(', ')}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _PolicyBadge extends StatelessWidget {
  const _PolicyBadge({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _PropertyChip extends StatelessWidget {
  const _PropertyChip({required this.property});
  final ApprovedProperty property;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hotel,
                size: 16,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 4),
              Text(
                property.propertyName,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
          Text(
            property.city,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          if (property.startingRate != null)
            Text(
              'From ${NumberFormat.currency(symbol: '\$').format(property.startingRate!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
        ],
      ),
    );
  }
}

class _CostCenterTile extends StatelessWidget {
  const _CostCenterTile({required this.costCenter});
  final CostCenter costCenter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              costCenter.code,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  costCenter.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (costCenter.department != null)
                  Text(
                    costCenter.department!,
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Error view
// ═══════════════════════════════════════════════════════════════════════════

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.error_outline,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        const Text(
          'Unable to load company profile',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton(onPressed: onRetry, child: const Text('Retry')),
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
