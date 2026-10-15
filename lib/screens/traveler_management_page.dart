// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:ECorpBooking
// SPDX-License-Identifier: Apache-2.0

/// Traveler Management (Travel Manager).
///
/// Company traveler roster, add/edit/remove travelers, traveler profiles
/// (name, email, phone, loyalty memberships, preferences), travel policy
/// assignment per traveler, and booking permissions (who can book for whom).

import 'package:flutter/material.dart';

import '../bff_client.dart';
import '../models.dart';

class TravelerManagementPage extends StatefulWidget {
  const TravelerManagementPage({
    super.key,
    required this.client,
    required this.company,
  });

  final BffClient client;
  final Company company;

  @override
  State<TravelerManagementPage> createState() => _TravelerManagementPageState();
}

class _TravelerManagementPageState extends State<TravelerManagementPage> {
  late Future<List<Traveler>> _future;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _future = widget.client.getTravelers(widget.company.id);
  }

  Future<void> _refresh() async {
    setState(() => _future = widget.client.getTravelers(widget.company.id));
    await _future;
  }

  void _addTraveler() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TravelerEditPage(
          client: widget.client,
          company: widget.company,
          traveler: null,
          onSaved: _refresh,
        ),
      ),
    );
  }

  void _editTraveler(Traveler traveler) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TravelerEditPage(
          client: widget.client,
          company: widget.company,
          traveler: traveler,
          onSaved: _refresh,
        ),
      ),
    );
  }

  Future<void> _removeTraveler(Traveler traveler) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Traveler?'),
        content: Text(
          'Remove ${traveler.fullName} from the company roster? '
          'They will no longer be able to book at corporate rates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.client.removeTraveler(widget.company.id, traveler.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${traveler.fullName} removed.')),
        );
        _refresh();
      }
    } on BffException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Remove failed: ${e.message}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traveler Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Traveler',
            onPressed: _addTraveler,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search travelers',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Traveler>>(
              future: _future,
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
                var list = snapshot.data ?? const [];
                if (_searchQuery.isNotEmpty) {
                  list = list
                      .where(
                        (t) =>
                            t.fullName.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ) ||
                            t.email.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ) ||
                            (t.department ?? '').toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ),
                      )
                      .toList();
                }
                if (list.isEmpty) {
                  return _EmptyRoster(onAdd: _addTraveler);
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _TravelerTile(
                    traveler: list[i],
                    onEdit: () => _editTraveler(list[i]),
                    onRemove: () => _removeTraveler(list[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Traveler tile
// ═══════════════════════════════════════════════════════════════════════════

class _TravelerTile extends StatelessWidget {
  const _TravelerTile({
    required this.traveler,
    required this.onEdit,
    required this.onRemove,
  });

  final Traveler traveler;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            '${traveler.firstName[0]}${traveler.lastName[0]}',
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          ),
        ),
        title: Row(
          children: [
            Text(
              traveler.fullName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                traveler.role.label,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            if (!traveler.isActive) ...[
              const SizedBox(width: 4),
              Text(
                '(inactive)',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(traveler.email, style: theme.textTheme.bodySmall),
            if (traveler.department != null || traveler.costCenter != null)
              Text(
                [
                  traveler.department,
                  traveler.costCenter != null
                      ? 'CC: ${traveler.costCenter}'
                      : null,
                ].whereType<String>().join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            if (traveler.canBookForOthers)
              Row(
                children: [
                  Icon(Icons.group, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Can book for others',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'remove') onRemove();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(
              value: 'remove',
              child: Text(
                'Remove',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Add / edit traveler
// ═══════════════════════════════════════════════════════════════════════════

class TravelerEditPage extends StatefulWidget {
  const TravelerEditPage({
    super.key,
    required this.client,
    required this.company,
    required this.traveler,
    required this.onSaved,
  });

  final BffClient client;
  final Company company;
  final Traveler? traveler; // null = add
  final VoidCallback onSaved;

  @override
  State<TravelerEditPage> createState() => _TravelerEditPageState();
}

class _TravelerEditPageState extends State<TravelerEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _department;
  late final TextEditingController _costCenter;
  late final TextEditingController _loyaltyProgram;
  late final TextEditingController _loyaltyNumber;
  TravelerRole _role = TravelerRole.traveler;
  bool _canBookForOthers = false;
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.traveler;
    _firstName = TextEditingController(text: t?.firstName ?? '');
    _lastName = TextEditingController(text: t?.lastName ?? '');
    _email = TextEditingController(text: t?.email ?? '');
    _phone = TextEditingController(text: t?.phone ?? '');
    _department = TextEditingController(text: t?.department ?? '');
    _costCenter = TextEditingController(text: t?.costCenter ?? '');
    _loyaltyProgram = TextEditingController(text: t?.loyaltyProgram ?? '');
    _loyaltyNumber = TextEditingController(text: t?.loyaltyNumber ?? '');
    _role = t?.role ?? TravelerRole.traveler;
    _canBookForOthers = t?.canBookForOthers ?? false;
    _isActive = t?.isActive ?? true;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _department.dispose();
    _costCenter.dispose();
    _loyaltyProgram.dispose();
    _loyaltyNumber.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final traveler = Traveler(
        id: widget.traveler?.id ?? '',
        companyId: widget.company.id,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        department: _department.text.trim().isEmpty
            ? null
            : _department.text.trim(),
        costCenter: _costCenter.text.trim().isEmpty
            ? null
            : _costCenter.text.trim(),
        role: _role,
        canBookForOthers: _canBookForOthers,
        isActive: _isActive,
        loyaltyProgram: _loyaltyProgram.text.trim().isEmpty
            ? null
            : _loyaltyProgram.text.trim(),
        loyaltyNumber: _loyaltyNumber.text.trim().isEmpty
            ? null
            : _loyaltyNumber.text.trim(),
      );
      if (widget.traveler == null) {
        await widget.client.addTraveler(widget.company.id, traveler);
      } else {
        await widget.client.updateTraveler(widget.company.id, traveler);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.traveler == null ? 'Traveler added.' : 'Traveler updated.',
            ),
          ),
        );
        widget.onSaved();
        Navigator.of(context).pop();
      }
    } on BffException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: ${e.message}')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.traveler == null;
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'Add Traveler' : 'Edit Traveler')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Name ──────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstName,
                    decoration: const InputDecoration(
                      labelText: 'First Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastName,
                    decoration: const InputDecoration(
                      labelText: 'Last Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Contact ────────────────────────────────────────────────
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(
                labelText: 'Email *',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(v.trim())) {
                  return 'Invalid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            // ── Department / cost center ───────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _department,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      prefixIcon: Icon(Icons.groups_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _costCenter,
                    decoration: const InputDecoration(
                      labelText: 'Cost Center',
                      prefixIcon: Icon(Icons.account_balance_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Role ──────────────────────────────────────────────────
            DropdownButtonFormField<TravelerRole>(
              value: _role,
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
              items: TravelerRole.values
                  .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _role = v ?? TravelerRole.traveler),
            ),
            const SizedBox(height: 16),

            // ── Permissions ───────────────────────────────────────────
            SwitchListTile(
              title: const Text('Can book for others'),
              subtitle: const Text(
                'Allow this traveler to book on behalf of other company members',
              ),
              value: _canBookForOthers,
              onChanged: (v) => setState(() => _canBookForOthers = v),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Active'),
              subtitle: const Text(
                'Inactive travelers cannot make bookings at corporate rates',
              ),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),

            // ── Loyalty ───────────────────────────────────────────────
            Text(
              'Loyalty Memberships (optional)',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _loyaltyProgram,
                    decoration: const InputDecoration(
                      labelText: 'Program',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _loyaltyNumber,
                    decoration: const InputDecoration(
                      labelText: 'Member Number',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Save ──────────────────────────────────────────────────
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isNew ? 'Add Traveler' : 'Save Changes'),
              ),
            ),
          ],
        ),
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
            const Text('Unable to load travelers'),
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

class _EmptyRoster extends StatelessWidget {
  const _EmptyRoster({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.group_add,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 16),
        Text(
          'No travelers yet',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Add your company travelers to let them book at corporate rates.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add),
            label: const Text('Add Traveler'),
          ),
        ),
      ],
    );
  }
}
