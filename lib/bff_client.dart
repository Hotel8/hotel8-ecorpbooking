// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:ECorpBooking
// SPDX-License-Identifier: Apache-2.0

/// Hcorp BFF client.
///
/// Thin HTTP client that calls the BFF proxy endpoints (see
/// `ecorpbooking/DESIGN.md` §4) which in turn
/// delegate to PMS / Payments / Loyalty / Post. All requests go through the
/// BFF server-side token guardian — Hcorp never talks to a backend directly.

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'models.dart';

class BffClient {
  BffClient({String? baseUrl, String? propertyId, http.Client? httpClient})
    : _baseUrl = baseUrl ?? _resolveBaseUrl(),
      _propertyId = propertyId ?? '',
      _httpClient = httpClient ?? http.Client();

  final String _baseUrl;

  /// Property the portal serves — from the App runtime context at
  /// bootstrap (`ecorpbooking/DESIGN.md` §2). PMS routes are property-scoped.
  final String _propertyId;
  final http.Client _httpClient;

  /// Resolve the BFF base URL. In production this is the corporate-scoped
  /// BFF domain (e.g. `https://bff.corp.demo-hotel.pms.sentin8.dev`).
  /// For local development fall back to the `HCORP_BFF_BASE_URL` env var or
  /// `http://localhost:8080`.
  static String _resolveBaseUrl() {
    const env = String.fromEnvironment('HCORP_BFF_BASE_URL', defaultValue: '');
    if (env.isNotEmpty) return env;

    if (kIsWeb) {
      // Same-origin: BFF served alongside the Flutter web app.
      return '';
    }
    return 'http://localhost:8080';
  }

  String _path(String p) => '$_baseUrl$p';

  Future<Map<String, dynamic>> _getJson(String path) async {
    final resp = await _httpClient.get(
      Uri.parse(_path(path)),
      headers: _headers(),
    );
    return _handle(resp);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final resp = await _httpClient.post(
      Uri.parse(_path(path)),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _handle(resp);
  }

  Future<Map<String, dynamic>> _putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final resp = await _httpClient.put(
      Uri.parse(_path(path)),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _handle(resp);
  }

  Future<Map<String, dynamic>> _deleteJson(String path) async {
    final resp = await _httpClient.delete(
      Uri.parse(_path(path)),
      headers: _headers(),
    );
    return _handle(resp);
  }

  Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<Map<String, dynamic>> _handle(http.Response resp) async {
    final body = resp.body.isEmpty ? '{}' : resp.body;
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(body) as Map<String, dynamic>;
    }
    String message;
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      message =
          decoded['message'] as String? ?? decoded['error'] as String? ?? body;
    } catch (_) {
      message = body;
    }
    throw BffException(resp.statusCode, message);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Authentication
  // ═════════════════════════════════════════════════════════════════════════

  /// `POST /proxy/auth/v1/sign-in` — corporate members authenticate with
  /// the standard env identity (no vertical-specific Auth endpoints; the
  /// company binding is a PMS CRM membership — `ecorpbooking/DESIGN.md` §4).
  ///
  /// Authenticates a corporate user with email + password. Returns the
  /// company context (code, name, SSO availability).
  Future<Company> corporateLogin({
    required String email,
    required String password,
    String? companyCode,
  }) async {
    final json = await _postJson('/proxy/auth/v1/sign-in', {
      'email': email,
      'password': password,
    });
    return Company.fromJson(json['company'] as Map<String, dynamic>? ?? json);
  }

  /// SSO — the standard BFF/OAuth redirect (companies with an IdP ride
  /// Auth's enterprise-connection SSO). No separate corporate SSO endpoint.
  ///
  /// SSO login — redirects to the company's identity provider.
  Future<void> corporateSso({required String companyCode}) async {
    // SSO redirects through the BFF → Auth enterprise connection for the
    // company's IdP; the round trip completes at /auth/callback with the
    // session cookie set — no direct response body.
    await _postJson('/proxy/auth/v1/sso-start', {'company_code': companyCode});
  }

  /// `GET /proxy/hotel8-pms/v1/properties/{pid}/profiles?profile_type=COMPANY&q=`
  /// — company-code verification resolves the company profile on the PMS
  /// CRM registry (real route; profile rows carry the company code).
  ///
  /// Verify a company code during registration / login.
  Future<Company> verifyCompanyCode(String code) async {
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/profiles?profile_type=COMPANY&q=${Uri.encodeComponent(code)}',
    );
    final items = (json['items'] as List<dynamic>?) ?? const [];
    if (items.isEmpty) {
      throw const BffException(404, 'Company code not recognized');
    }
    return Company.fromJson(items.first as Map<String, dynamic>);
  }

  /// `GET .../companies/{id}/admin-provisioning` — whether the company still
  /// needs its first corporate admin (no IdP + no bound ADMIN) — the
  /// provisioning-flow decision after company-code verification
  /// (ecorpbooking/DESIGN.md §4).
  Future<bool> companyRequiresProvisioning(String companyId) async {
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/companies/$companyId/admin-provisioning',
    );
    return json['requires_provisioning'] as bool? ?? false;
  }

  /// `PUT .../companies/{id}/admin-provisioning` — provision the first
  /// corporate admin for a company without an IdP (ECRP-3).
  Future<void> provisionCompanyAdmin({
    required String companyId,
    required String email,
    String firstName = '',
    String lastName = 'Admin',
  }) async {
    await _putJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/companies/$companyId/admin-provisioning',
      {'email': email, 'first_name': firstName, 'last_name': lastName},
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Company profile
  // ═════════════════════════════════════════════════════════════════════════

  /// `GET /proxy/hotel8-pms/v1/properties/{p}/profiles/{id}`
  Future<CompanyProfile> getCompanyProfile(String companyId) async {
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId/profiles/$companyId',
    );
    return CompanyProfile.fromJson(json);
  }

  /// `PUT /proxy/hotel8-pms/v1/properties/{p}/profiles/{id}`
  Future<CompanyProfile> updateCompanyProfile(
    String companyId,
    CompanyProfile profile,
  ) async {
    final json = await _putJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/profiles/$companyId',
      profile.toJson(),
    );
    return CompanyProfile.fromJson(json);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Corporate rates / availability
  // ═════════════════════════════════════════════════════════════════════════

  /// `GET /proxy/hotel8-pms/v1/properties/{p}/negotiated-rate-plans` —
  /// the negotiated rate plans linked to the company (real PMS route; the
  /// link-company endpoint binds them).
  Future<List<CorporateRate>> getCorporateRates({
    required String companyId,
    String? propertyCode,
  }) async {
    final pid = propertyCode ?? _propertyId;
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$pid/negotiated-rate-plans'
      '?company_id=${Uri.encodeComponent(companyId)}',
    );
    final list = (json['items'] as List<dynamic>?) ?? const [];
    return list
        .map((e) => CorporateRate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /proxy/hotel8-pms/v1/properties/{p}/availability`
  ///
  /// `POST /proxy/hotel8-pms/v1/properties/{p}/corporate-availability`
  ///
  /// Search availability for corporate-negotiated rates only. The server
  /// applies the company rate-mix policy (pms/DESIGN.md §4): only plans
  /// linked to the company profile are returned — public rates are withheld.
  Future<List<SearchResult>> searchCorporateAvailability(
    CorporateSearchRequest request, {
    required String companyId,
  }) async {
    final body = request.toJson();
    body['company_profile_id'] = companyId;
    final json = await _postJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId/corporate-availability',
      body,
    );
    final roomTypes = (json['room_types'] as List<dynamic>?) ?? const [];
    final results = <SearchResult>[];
    for (final rt in roomTypes) {
      final map = rt as Map<String, dynamic>;
      final plans = (map['rate_plans'] as List<dynamic>?) ?? const [];
      for (final rp in plans) {
        final plan = rp as Map<String, dynamic>;
        results.add(
          SearchResult(
            rate: CorporateRate(
              id: plan['rate_plan_id'] as String,
              ratePlanCode: plan['rate_plan_code'] as String,
              ratePlanName: plan['rate_plan_name'] as String? ?? '',
              propertyCode: map['room_type_code'] as String? ?? '',
              propertyName: map['room_type_name'] as String? ?? '',
              propertyCity: '',
              roomTypeCode: map['room_type_code'] as String? ?? '',
              roomTypeName: map['room_type_name'] as String? ?? '',
              corporateRate:
                  double.tryParse(plan['rate_amount'] as String? ?? '') ?? 0.0,
              publicRate:
                  double.tryParse(plan['rate_amount'] as String? ?? '') ?? 0.0,
              currencyCode: plan['currency_code'] as String? ?? 'USD',
            ),
            policyCompliant: true,
          ),
        );
      }
    }
    return results;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Bookings
  // ═════════════════════════════════════════════════════════════════════════

  /// `POST /proxy/hotel8-pms/v1/properties/{p}/reservations`
  Future<CorporateBooking> createCorporateBooking(
    String companyId,
    CorporateBookingCreate booking,
  ) async {
    final json = await _postJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId/reservations',
      booking.toJson(),
    );
    return CorporateBooking.fromJson(json);
  }

  /// `GET /proxy/hotel8-pms/v1/properties/{p}/reservations?guest_profile_id=`
  Future<List<CorporateBooking>> getBookings({
    required String companyId,
    String? travelerId,
    bool upcoming = true,
  }) async {
    final qs = <String>['company_id=$companyId'];
    if (travelerId != null) qs.add('traveler_id=$travelerId');
    qs.add('upcoming=$upcoming');
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/reservations?guest_profile_id=${Uri.encodeComponent(companyId)}'
      '&${qs.join('&')}',
    );
    final list =
        json['reservations'] as List<dynamic>? ??
        json['bookings'] as List<dynamic>? ??
        json['data'] as List<dynamic>? ??
        const [];
    return list
        .map((e) => CorporateBooking.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /proxy/hotel8-pms/v1/properties/{p}/reservations/{id}/cancel`
  Future<void> cancelBooking(String companyId, String bookingId) async {
    await _putJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/reservations/$bookingId/cancel',
      {},
    );
  }

  /// `PUT /proxy/hotel8-pms/v1/properties/{p}/reservations/{id}`
  Future<CorporateBooking> modifyBooking(
    String companyId,
    String bookingId,
    Map<String, dynamic> changes,
  ) async {
    final json = await _putJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/reservations/$bookingId',
      changes,
    );
    return CorporateBooking.fromJson(json);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Traveler management
  // ═════════════════════════════════════════════════════════════════════════

  /// Traveler roster — company-linked GUEST profiles (profile_id chain via
  /// /pms/profiles; the roster is the company's linked-guest list).
  Future<List<Traveler>> getTravelers(String companyId) async {
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId/profiles',
    );
    final list =
        json['travelers'] as List<dynamic>? ??
        json['data'] as List<dynamic>? ??
        const [];
    return list
        .map((e) => Traveler.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /proxy/hotel8-pms/v1/properties/{p}/profiles` — roster add.
  Future<Traveler> addTraveler(String companyId, Traveler traveler) async {
    final json = await _postJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId/profiles',
      traveler.toJson(),
    );
    return Traveler.fromJson(json);
  }

  /// `PUT` rides the PMS profile update (preferences/loyalty routes).
  Future<Traveler> updateTraveler(String companyId, Traveler traveler) async {
    final json = await _putJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/profiles/${traveler.id}',
      traveler.toJson(),
    );
    return Traveler.fromJson(json);
  }

  /// Roster remove — via the profile update route.
  Future<void> removeTraveler(String companyId, String travelerId) async {
    await _deleteJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/profiles/$travelerId',
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Travel policies
  // ═════════════════════════════════════════════════════════════════════════

  /// Travel policies — company profile field set (PMS CRM).
  Future<List<TravelPolicy>> getTravelPolicies(String companyId) async {
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId/profiles/\$companyId/policies',
    );
    final list =
        json['policies'] as List<dynamic>? ??
        json['data'] as List<dynamic>? ??
        const [];
    return list
        .map((e) => TravelPolicy.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Policy updates ride the company-profile update route.
  Future<TravelPolicy> updateTravelPolicy(
    String companyId,
    TravelPolicy policy,
  ) async {
    final json = await _putJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId/profiles/\$companyId/policies/${policy.id}',
      policy.toJson(),
    );
    return TravelPolicy.fromJson(json);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Announcements
  // ═════════════════════════════════════════════════════════════════════════

  /// `GET /proxy/post/v1/messages?category=ANNOUNCEMENT` — company
  /// announcements ride Sentin8:Post's message list.
  Future<List<Announcement>> getAnnouncements(String companyId) async {
    final json = await _getJson(
      '/proxy/post/v1/messages?category=ANNOUNCEMENT',
    );
    final list =
        json['announcements'] as List<dynamic>? ??
        json['data'] as List<dynamic>? ??
        const [];
    return list
        .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Reports
  // ═════════════════════════════════════════════════════════════════════════

  /// `GET /proxy/hotel8-pms/v1/properties/{p}/reports/reservation-summary`
  Future<ReportSummary> getReportSummary(
    String companyId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final qs = <String>[];
    if (fromDate != null) qs.add('from=${_dateStr(fromDate)}');
    if (toDate != null) qs.add('to=${_dateStr(toDate)}');
    final query = qs.isEmpty ? '' : '?${qs.join('&')}';
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId/reports/reservation-summary\$query',
    );
    return ReportSummary.fromJson(json);
  }

  /// `GET /proxy/hotel8-pms/v1/properties/{p}/reports/channel-performance`
  // ═════════════════════════════════════════════════════════════════════
  // Corporate credit methods + company bindings (PMS corporate surfaces)
  // ═════════════════════════════════════════════════════════════════════

  /// `GET .../companies/{id}/payment-methods?approved_only=true` — the
  /// credit-approved methods (post-pay / bill-to-company) checkout can bill.
  Future<List<CreditMethod>> getApprovedCreditMethods(String companyId) async {
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/companies/$companyId/payment-methods?approved_only=true',
    );
    final list = (json['items'] as List<dynamic>?) ?? const [];
    return list
        .map((e) => CreditMethod.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET .../companies/by-traveler/{profile_id}` — companies the signed-in
  /// traveler is bound to (multi-company session switcher).
  Future<List<CompanyBinding>> getCompanyBindings(
    String travelerProfileId,
  ) async {
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/companies/by-traveler/$travelerProfileId',
    );
    final list = (json['items'] as List<dynamic>?) ?? const [];
    return list
        .map((e) => CompanyBinding.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET .../companies/{id}/users` — the company's traveler roster
  /// (binding rows with role-at-company).
  Future<List<Map<String, dynamic>>> getCompanyUsers(String companyId) async {
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/companies/$companyId/users',
    );
    final list = (json['items'] as List<dynamic>?) ?? const [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<List<ReportByProperty>> getReportByProperty(
    String companyId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final qs = <String>[];
    if (fromDate != null) qs.add('from=${_dateStr(fromDate)}');
    if (toDate != null) qs.add('to=${_dateStr(toDate)}');
    final query = qs.isEmpty ? '' : '?${qs.join('&')}';
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId/reports/channel-performance\$query',
    );
    final list =
        json['properties'] as List<dynamic>? ??
        json['data'] as List<dynamic>? ??
        const [];
    return list
        .map((e) => ReportByProperty.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Traveler-level breakdown rides the guest-history report.
  Future<List<ReportByTraveler>> getReportByTraveler(
    String companyId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final qs = <String>[];
    if (fromDate != null) qs.add('from=${_dateStr(fromDate)}');
    if (toDate != null) qs.add('to=${_dateStr(toDate)}');
    final query = qs.isEmpty ? '' : '?${qs.join('&')}';
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId/reports/guest-history\$query',
    );
    final list =
        json['travelers'] as List<dynamic>? ??
        json['data'] as List<dynamic>? ??
        const [];
    return list
        .map((e) => ReportByTraveler.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Monthly breakdown rides the occupancy trend report.
  Future<List<ReportByMonth>> getReportByMonth(
    String companyId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final qs = <String>[];
    if (fromDate != null) qs.add('from=${_dateStr(fromDate)}');
    if (toDate != null) qs.add('to=${_dateStr(toDate)}');
    final query = qs.isEmpty ? '' : '?${qs.join('&')}';
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId/reports/occupancy\$query',
    );
    final list =
        json['months'] as List<dynamic>? ??
        json['data'] as List<dynamic>? ??
        const [];
    return list
        .map((e) => ReportByMonth.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void close() => _httpClient.close();
}

class BffException implements Exception {
  final int statusCode;
  final String message;
  const BffException(this.statusCode, this.message);

  @override
  String toString() => 'BffException($statusCode): $message';
}

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
