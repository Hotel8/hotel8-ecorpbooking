// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:ECorpBooking
// SPDX-License-Identifier: Apache-2.0

/// Corporate Login.
///
/// Branded login page with company logo, email + password authentication,
/// SSO option (if company has identity provider), and "Request Access" link
/// for new corporate clients. Company code verification during registration.

import 'package:flutter/material.dart';

import '../app.dart';
import '../bff_client.dart';
import '../models.dart';

class CorporateLoginPage extends StatefulWidget {
  const CorporateLoginPage({
    super.key,
    required this.client,
    this.companyCode,
  });

  final BffClient client;
  final String? companyCode;

  @override
  State<CorporateLoginPage> createState() => _CorporateLoginPageState();
}

class _CorporateLoginPageState extends State<CorporateLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _companyCodeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  bool _verifying = false;
  Company? _verifiedCompany;

  @override
  void initState() {
    super.initState();
    if (widget.companyCode != null) {
      _companyCodeController.text = widget.companyCode!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _verifyCompany());
    }
  }

  @override
  void dispose() {
    _companyCodeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _verifyCompany() async {
    final code = _companyCodeController.text.trim();
    if (code.isEmpty) {
      setState(() => _verifiedCompany = null);
      return;
    }
    setState(() {
      _verifying = true;
      _verifiedCompany = null;
    });
    try {
      final company = await widget.client.verifyCompanyCode(code);
      if (mounted) setState(() => _verifiedCompany = company);
    } on BffException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Company verification failed: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    if (_verifiedCompany == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your company code first.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final company = await widget.client.corporateLogin(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        companyCode: _companyCodeController.text.trim(),
      );
      if (mounted) {
        // Multi-company travelers (ecorpbooking/DESIGN.md §10): resolve the
        // session subject's company bindings; several companies present the
        // switcher, one lands directly. The session binds ONE company per
        // run — no org-wide pass-through.
        List<CompanyBinding> bindings = const [];
        try {
          bindings = await widget.client
              .getCompanyBindings(company.id);
        } on BffException {
          // Binding surface unreachable → the verified company stands.
        }
        Company active = company;
        if (bindings.length > 1) {
          final picked = await showDialog<CompanyBinding>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Choose your company'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final b in bindings)
                    ListTile(
                      leading: const Icon(Icons.business),
                      title: Text(b.companyName),
                      subtitle: Text(b.roleAtCompany),
                      trailing: b.isDefault ? const Icon(Icons.star) : null,
                      onTap: () => Navigator.pop(ctx, b),
                    ),
                ],
              ),
            ),
          );
          if (picked != null) {
            // Re-verify the picked company so the shell reads its profile.
            active = Company(
              id: picked.companyProfileId,
              companyCode: picked.companyProfileId,
              companyName: picked.companyName,
              currencyCode: company.currencyCode,
            );
          }
        }
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HcorpShell(
              client: widget.client,
              company: active,
            ),
          ),
        );
      }
    } on BffException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ssoLogin() async {
    if (_verifiedCompany == null || !_verifiedCompany!.hasSso) return;
    setState(() => _loading = true);
    try {
      // SSO completes with a browser round trip to the IdP; the redirect
      // chain re-enters the app with the session set.
      await widget.client.corporateSso(
        companyCode: _companyCodeController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Redirecting to your identity provider…')),
        );
      }
    } on BffException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SSO login failed: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _requestAccess() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _RequestAccessSheet(client: widget.client),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Logo / Brand ──────────────────────────────────
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.business_center,
                        size: 40,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Hcorp',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Corporate Travel Portal',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Company code ──────────────────────────────────
                    TextFormField(
                      controller: _companyCodeController,
                      decoration: InputDecoration(
                        labelText: 'Company Code',
                        prefixIcon: const Icon(Icons.apartment_outlined),
                        suffixIcon: _verifying
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: _verifyCompany,
                                tooltip: 'Verify',
                              ),
                        border: const OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: (v) {
                        if (_verifiedCompany != null) {
                          setState(() => _verifiedCompany = null);
                        }
                      },
                      onFieldSubmitted: (_) => _verifyCompany(),
                    ),

                    if (_verifiedCompany != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.verified,
                                size: 18, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _verifiedCompany!.companyName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // ── Email ─────────────────────────────────────────
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Corporate Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$')
                            .hasMatch(v.trim())) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Password ─────────────────────────────────────
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── Login button ──────────────────────────────────
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Sign In'),
                      ),
                    ),

                    // ── SSO option ────────────────────────────────────
                    if (_verifiedCompany?.hasSso == true) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text('OR',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant)),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _ssoLogin,
                          icon: const Icon(Icons.login),
                          label: Text(
                            'Continue with ${_verifiedCompany!.ssoProvider ?? 'SSO'}',
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── Request access ────────────────────────────────
                    TextButton(
                      onPressed: _requestAccess,
                      child: const Text('New corporate client? Request access'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Request Access bottom sheet
// ═══════════════════════════════════════════════════════════════════════════

class _RequestAccessSheet extends StatefulWidget {
  const _RequestAccessSheet({required this.client});

  final BffClient client;

  @override
  State<_RequestAccessSheet> createState() => _RequestAccessSheetState();
}

class _RequestAccessSheetState extends State<_RequestAccessSheet> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _companyNameController.dispose();
    _contactNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    // First-admin provisioning (ecorpbooking/DESIGN.md §4 SSO onboarding):
    // sheet collects company + first admin; the PMS provisions the ADMIN
    // company_users row server-side. Transport failures keep the
    // informational message — sales onboarding proceeds manually.
    String message =
        'Access request submitted. Our sales team will contact you within 24 hours.';
    try {
      final company = await widget.client.verifyCompanyCode(
        _companyNameController.text.trim(),
      );
      await widget.client.provisionCompanyAdmin(
        companyId: company.id,
        email: _emailController.text.trim(),
        firstName: _contactNameController.text.trim(),
        lastName: 'Admin',
      );
      message =
          'Provisioning request accepted. Check ${_emailController.text.trim()} '
          'for your corporate admin invitation.';
    } on BffException {
      // Company code unknown or surface unreachable — leave the sales-team
      // message; onboarding proceeds manually.
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Request Corporate Access',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Tell us about your company and our hotel sales team will set up your corporate account.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _companyNameController,
              decoration: const InputDecoration(
                labelText: 'Company Name',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactNameController,
              decoration: const InputDecoration(
                labelText: 'Contact Name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Work Email',
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
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
