// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:ECorpBooking
// SPDX-License-Identifier: Apache-2.0

/// Hcorp data models.
///
/// Simple Dart classes mirroring the PMS corporate contract shapes (see
/// `ecorpbooking/DESIGN.md` §3–4) and the BFF
/// proxy surface for Hcorp. Hcorp is the corporate counterpart to Hbook —
/// it serves business travelers with negotiated rates, company codes,
/// and policy enforcement rather than public leisure rates.

// ═══════════════════════════════════════════════════════════════════════════
// Company
// ═══════════════════════════════════════════════════════════════════════════

class Company {
  final String id;
  final String companyCode;
  final String companyName;
  final String? domain;
  final String? industry;
  final String? taxId;
  final String currencyCode;
  final bool hasSso;
  final String? ssoProvider;
  final bool postPayApproved;
  final bool billToCompanyApproved;
  final double? creditLimit;
  final String? paymentTerms;
  final DateTime? createdAt;

  const Company({
    required this.id,
    required this.companyCode,
    required this.companyName,
    this.domain,
    this.industry,
    this.taxId,
    this.currencyCode = 'USD',
    this.hasSso = false,
    this.ssoProvider,
    this.postPayApproved = false,
    this.billToCompanyApproved = false,
    this.creditLimit,
    this.paymentTerms,
    this.createdAt,
  });

  factory Company.fromJson(Map<String, dynamic> json) => Company(
    id: json['id'] as String,
    companyCode: json['company_code'] as String,
    companyName: json['company_name'] as String,
    domain: json['domain'] as String?,
    industry: json['industry'] as String?,
    taxId: json['tax_id'] as String?,
    currencyCode: json['currency_code'] as String? ?? 'USD',
    hasSso: json['has_sso'] as bool? ?? false,
    ssoProvider: json['sso_provider'] as String?,
    postPayApproved: json['post_pay_approved'] as bool? ?? false,
    billToCompanyApproved: json['bill_to_company_approved'] as bool? ?? false,
    creditLimit: (json['credit_limit'] as num?)?.toDouble(),
    paymentTerms: json['payment_terms'] as String?,
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'company_code': companyCode,
    'company_name': companyName,
    'domain': domain,
    'industry': industry,
    'tax_id': taxId,
    'currency_code': currencyCode,
    'has_sso': hasSso,
    'sso_provider': ssoProvider,
    'post_pay_approved': postPayApproved,
    'bill_to_company_approved': billToCompanyApproved,
    'credit_limit': creditLimit,
    'payment_terms': paymentTerms,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// Address (shared)
// ═══════════════════════════════════════════════════════════════════════════

class Address {
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;

  const Address({
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
  });

  factory Address.fromJson(Map<String, dynamic> json) => Address(
    addressLine1: json['address_line1'] as String?,
    addressLine2: json['address_line2'] as String?,
    city: json['city'] as String?,
    state: json['state'] as String?,
    postalCode: json['postal_code'] as String?,
    country: json['country'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'address_line1': addressLine1,
    'address_line2': addressLine2,
    'city': city,
    'state': state,
    'postal_code': postalCode,
    'country': country,
  };

  String get oneLine => [
    addressLine1,
    addressLine2,
    city,
    state,
    postalCode,
    country,
  ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
}

// ═══════════════════════════════════════════════════════════════════════════
// Corporate Rate
// ═══════════════════════════════════════════════════════════════════════════

class CorporateRate {
  final String id;
  final String ratePlanCode;
  final String ratePlanName;
  final String propertyCode;
  final String propertyName;
  final String propertyCity;
  final String roomTypeCode;
  final String roomTypeName;
  final double corporateRate;
  final double publicRate;
  final String currencyCode;
  final String? cancellationPolicy;
  final String? guaranteePolicy;
  final bool breakfastIncluded;
  final bool isAvailable;

  const CorporateRate({
    required this.id,
    required this.ratePlanCode,
    required this.ratePlanName,
    required this.propertyCode,
    required this.propertyName,
    required this.propertyCity,
    required this.roomTypeCode,
    required this.roomTypeName,
    required this.corporateRate,
    required this.publicRate,
    this.currencyCode = 'USD',
    this.cancellationPolicy,
    this.guaranteePolicy,
    this.breakfastIncluded = false,
    this.isAvailable = true,
  });

  factory CorporateRate.fromJson(Map<String, dynamic> json) => CorporateRate(
    id: json['id'] as String,
    ratePlanCode: json['rate_plan_code'] as String,
    ratePlanName: json['rate_plan_name'] as String? ?? '',
    propertyCode: json['property_code'] as String,
    propertyName: json['property_name'] as String? ?? '',
    propertyCity: json['property_city'] as String? ?? '',
    roomTypeCode: json['room_type_code'] as String,
    roomTypeName: json['room_type_name'] as String? ?? '',
    corporateRate: (json['corporate_rate'] as num?)?.toDouble() ?? 0.0,
    publicRate: (json['public_rate'] as num?)?.toDouble() ?? 0.0,
    currencyCode: json['currency_code'] as String? ?? 'USD',
    cancellationPolicy: json['cancellation_policy'] as String?,
    guaranteePolicy: json['guarantee_policy'] as String?,
    breakfastIncluded: json['breakfast_included'] as bool? ?? false,
    isAvailable: json['is_available'] as bool? ?? true,
  );

  double get savings => publicRate - corporateRate;
  double get savingsPercent =>
      publicRate > 0 ? (savings / publicRate * 100) : 0.0;
}

// ═══════════════════════════════════════════════════════════════════════════
// Traveler
// ═══════════════════════════════════════════════════════════════════════════

enum TravelerRole { traveler, travelManager, admin, bookingAgent }

extension TravelerRoleX on TravelerRole {
  static TravelerRole fromString(String s) {
    return TravelerRole.values.firstWhere(
      (e) => e.name.toLowerCase() == s.toLowerCase().replaceAll('_', ''),
      orElse: () => TravelerRole.traveler,
    );
  }

  String get label {
    switch (this) {
      case TravelerRole.traveler:
        return 'Traveler';
      case TravelerRole.travelManager:
        return 'Travel Manager';
      case TravelerRole.admin:
        return 'Administrator';
      case TravelerRole.bookingAgent:
        return 'Booking Agent';
    }
  }
}

class Traveler {
  final String id;
  final String companyId;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? department;
  final String? costCenter;
  final TravelerRole role;
  final bool canBookForOthers;
  final bool isActive;
  final String? loyaltyProgram;
  final String? loyaltyNumber;
  final List<String> preferences;
  final String? assignedPolicyId;

  const Traveler({
    required this.id,
    required this.companyId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.department,
    this.costCenter,
    this.role = TravelerRole.traveler,
    this.canBookForOthers = false,
    this.isActive = true,
    this.loyaltyProgram,
    this.loyaltyNumber,
    this.preferences = const [],
    this.assignedPolicyId,
  });

  factory Traveler.fromJson(Map<String, dynamic> json) => Traveler(
    id: json['id'] as String,
    companyId: json['company_id'] as String,
    firstName: json['first_name'] as String,
    lastName: json['last_name'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String?,
    department: json['department'] as String?,
    costCenter: json['cost_center'] as String?,
    role: TravelerRoleX.fromString(json['role'] as String? ?? 'traveler'),
    canBookForOthers: json['can_book_for_others'] as bool? ?? false,
    isActive: json['is_active'] as bool? ?? true,
    loyaltyProgram: json['loyalty_program'] as String?,
    loyaltyNumber: json['loyalty_number'] as String?,
    preferences:
        (json['preferences'] as List<dynamic>?)?.cast<String>() ?? const [],
    assignedPolicyId: json['assigned_policy_id'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'company_id': companyId,
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'phone': phone,
    'department': department,
    'cost_center': costCenter,
    'role': role.name,
    'can_book_for_others': canBookForOthers,
    'is_active': isActive,
    'loyalty_program': loyaltyProgram,
    'loyalty_number': loyaltyNumber,
    'preferences': preferences,
    'assigned_policy_id': assignedPolicyId,
  };

  String get fullName => '$firstName $lastName';
}

// ═══════════════════════════════════════════════════════════════════════════
// Corporate Booking
// ═══════════════════════════════════════════════════════════════════════════

enum CorporateBookingStatus {
  pending,
  confirmed,
  checkedIn,
  checkedOut,
  cancelled,
  noShow;

  static CorporateBookingStatus fromString(String s) {
    return CorporateBookingStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == s.toLowerCase().replaceAll('_', ''),
      orElse: () => CorporateBookingStatus.confirmed,
    );
  }

  String get label {
    switch (this) {
      case CorporateBookingStatus.pending:
        return 'Pending';
      case CorporateBookingStatus.confirmed:
        return 'Confirmed';
      case CorporateBookingStatus.checkedIn:
        return 'Checked In';
      case CorporateBookingStatus.checkedOut:
        return 'Checked Out';
      case CorporateBookingStatus.cancelled:
        return 'Cancelled';
      case CorporateBookingStatus.noShow:
        return 'No Show';
    }
  }

  bool get isUpcoming =>
      this == CorporateBookingStatus.pending ||
      this == CorporateBookingStatus.confirmed;
}

enum PaymentMethod { creditCard, postPay, billToCompany }

extension PaymentMethodX on PaymentMethod {
  static PaymentMethod fromString(String? s) {
    switch (s?.toLowerCase()) {
      case 'post_pay':
      case 'postpay':
      case 'invoice':
        return PaymentMethod.postPay;
      case 'bill_to_company':
      case 'billtocompany':
        return PaymentMethod.billToCompany;
      default:
        return PaymentMethod.creditCard;
    }
  }

  String get label {
    switch (this) {
      case PaymentMethod.creditCard:
        return 'Credit Card';
      case PaymentMethod.postPay:
        return 'Post-Pay (Invoice)';
      case PaymentMethod.billToCompany:
        return 'Bill to Company';
    }
  }

  String get apiValue {
    switch (this) {
      case PaymentMethod.creditCard:
        return 'credit_card';
      case PaymentMethod.postPay:
        return 'post_pay';
      case PaymentMethod.billToCompany:
        return 'bill_to_company';
    }
  }
}

class CorporateBooking {
  final String id;
  final String confirmationNumber;
  final String companyId;
  final String travelerId;
  final String travelerName;
  final CorporateBookingStatus status;
  final String propertyCode;
  final String propertyName;
  final String propertyCity;
  final DateTime arrivalDate;
  final DateTime departureDate;
  final int numberOfNights;
  final int numberOfRooms;
  final int numberOfGuests;
  final String roomTypeName;
  final String ratePlanName;
  final double rateAmount;
  final double publicRateAmount;
  final String currencyCode;
  final PaymentMethod paymentMethod;
  final String? poNumber;
  final String? projectCode;
  final String? costCenter;
  final String? purposeOfTravel;
  final bool policyCompliant;
  final String? policyViolationReason;
  final DateTime createdAt;

  const CorporateBooking({
    required this.id,
    required this.confirmationNumber,
    required this.companyId,
    required this.travelerId,
    required this.travelerName,
    required this.status,
    required this.propertyCode,
    required this.propertyName,
    required this.propertyCity,
    required this.arrivalDate,
    required this.departureDate,
    required this.numberOfNights,
    required this.numberOfRooms,
    required this.numberOfGuests,
    required this.roomTypeName,
    required this.ratePlanName,
    required this.rateAmount,
    required this.publicRateAmount,
    this.currencyCode = 'USD',
    this.paymentMethod = PaymentMethod.creditCard,
    this.poNumber,
    this.projectCode,
    this.costCenter,
    this.purposeOfTravel,
    this.policyCompliant = true,
    this.policyViolationReason,
    required this.createdAt,
  });

  factory CorporateBooking.fromJson(
    Map<String, dynamic> json,
  ) => CorporateBooking(
    id: json['id'] as String,
    confirmationNumber: json['confirmation_number'] as String? ?? '',
    companyId: json['company_id'] as String,
    travelerId: json['traveler_id'] as String,
    travelerName: json['traveler_name'] as String? ?? '',
    status: CorporateBookingStatus.fromString(
      json['status'] as String? ?? 'confirmed',
    ),
    propertyCode: json['property_code'] as String,
    propertyName: json['property_name'] as String? ?? '',
    propertyCity: json['property_city'] as String? ?? '',
    arrivalDate:
        DateTime.tryParse(json['arrival_date'] as String? ?? '') ??
        DateTime.now(),
    departureDate:
        DateTime.tryParse(json['departure_date'] as String? ?? '') ??
        DateTime.now(),
    numberOfNights: (json['number_of_nights'] as num?)?.toInt() ?? 1,
    numberOfRooms: (json['number_of_rooms'] as num?)?.toInt() ?? 1,
    numberOfGuests: (json['number_of_guests'] as num?)?.toInt() ?? 1,
    roomTypeName: json['room_type_name'] as String? ?? '',
    ratePlanName: json['rate_plan_name'] as String? ?? '',
    rateAmount: (json['rate_amount'] as num?)?.toDouble() ?? 0.0,
    publicRateAmount: (json['public_rate_amount'] as num?)?.toDouble() ?? 0.0,
    currencyCode: json['currency_code'] as String? ?? 'USD',
    paymentMethod: PaymentMethodX.fromString(json['payment_method'] as String?),
    poNumber: json['po_number'] as String?,
    projectCode: json['project_code'] as String?,
    costCenter: json['cost_center'] as String?,
    purposeOfTravel: json['purpose_of_travel'] as String?,
    policyCompliant: json['policy_compliant'] as bool? ?? true,
    policyViolationReason: json['policy_violation_reason'] as String?,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
  );

  double get savings =>
      publicRateAmount > 0 ? publicRateAmount - rateAmount : 0.0;
}

class CorporateBookingCreate {
  final DateTime arrivalDate;
  final DateTime departureDate;
  final int numberOfRooms;
  final int numberOfGuests;
  final String propertyCode;
  final String roomTypeCode;
  final String ratePlanCode;
  final String travelerId;
  final PaymentMethod paymentMethod;
  final String? poNumber;
  final String? projectCode;
  final String? costCenter;
  final String? purposeOfTravel;
  final String? creditCardToken;
  final String? specialRequests;

  const CorporateBookingCreate({
    required this.arrivalDate,
    required this.departureDate,
    this.numberOfRooms = 1,
    this.numberOfGuests = 1,
    required this.propertyCode,
    required this.roomTypeCode,
    required this.ratePlanCode,
    required this.travelerId,
    this.paymentMethod = PaymentMethod.creditCard,
    this.poNumber,
    this.projectCode,
    this.costCenter,
    this.purposeOfTravel,
    this.creditCardToken,
    this.specialRequests,
  });

  Map<String, dynamic> toJson() => {
    'arrival_date': _dateStr(arrivalDate),
    'departure_date': _dateStr(departureDate),
    'number_of_rooms': numberOfRooms,
    'number_of_guests': numberOfGuests,
    'property_code': propertyCode,
    'room_type_code': roomTypeCode,
    'rate_plan_code': ratePlanCode,
    'traveler_id': travelerId,
    'payment_method': paymentMethod.apiValue,
    'po_number': poNumber,
    'project_code': projectCode,
    'cost_center': costCenter,
    'purpose_of_travel': purposeOfTravel,
    'credit_card_token': creditCardToken,
    'special_requests': specialRequests,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// Travel Policy
// ═══════════════════════════════════════════════════════════════════════════

class TravelPolicy {
  final String id;
  final String companyId;
  final String policyName;
  final double maxRatePerNight;
  final String currencyCode;
  final int maxAdvanceDays;
  final int minLeadDays;
  final List<String> approvedPropertyCodes;
  final List<String> approvedCities;
  final bool requireApprovalForOutPolicy;
  final bool allowWeekendBooking;
  final bool requirePurposeOfTravel;
  final List<String> allowedPaymentMethods;
  final bool isActive;

  const TravelPolicy({
    required this.id,
    required this.companyId,
    required this.policyName,
    this.maxRatePerNight = 0,
    this.currencyCode = 'USD',
    this.maxAdvanceDays = 90,
    this.minLeadDays = 0,
    this.approvedPropertyCodes = const [],
    this.approvedCities = const [],
    this.requireApprovalForOutPolicy = true,
    this.allowWeekendBooking = true,
    this.requirePurposeOfTravel = false,
    this.allowedPaymentMethods = const [],
    this.isActive = true,
  });

  factory TravelPolicy.fromJson(Map<String, dynamic> json) => TravelPolicy(
    id: json['id'] as String,
    companyId: json['company_id'] as String,
    policyName: json['policy_name'] as String? ?? '',
    maxRatePerNight: (json['max_rate_per_night'] as num?)?.toDouble() ?? 0,
    currencyCode: json['currency_code'] as String? ?? 'USD',
    maxAdvanceDays: (json['max_advance_days'] as num?)?.toInt() ?? 90,
    minLeadDays: (json['min_lead_days'] as num?)?.toInt() ?? 0,
    approvedPropertyCodes:
        (json['approved_property_codes'] as List<dynamic>?)?.cast<String>() ??
        const [],
    approvedCities:
        (json['approved_cities'] as List<dynamic>?)?.cast<String>() ?? const [],
    requireApprovalForOutPolicy:
        json['require_approval_for_out_policy'] as bool? ?? true,
    allowWeekendBooking: json['allow_weekend_booking'] as bool? ?? true,
    requirePurposeOfTravel: json['require_purpose_of_travel'] as bool? ?? false,
    allowedPaymentMethods:
        (json['allowed_payment_methods'] as List<dynamic>?)?.cast<String>() ??
        const [],
    isActive: json['is_active'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'company_id': companyId,
    'policy_name': policyName,
    'max_rate_per_night': maxRatePerNight,
    'currency_code': currencyCode,
    'max_advance_days': maxAdvanceDays,
    'min_lead_days': minLeadDays,
    'approved_property_codes': approvedPropertyCodes,
    'approved_cities': approvedCities,
    'require_approval_for_out_policy': requireApprovalForOutPolicy,
    'allow_weekend_booking': allowWeekendBooking,
    'require_purpose_of_travel': requirePurposeOfTravel,
    'allowed_payment_methods': allowedPaymentMethods,
    'is_active': isActive,
  };

  /// Check whether a given rate is within the policy cap.
  bool isRateCompliant(double nightlyRate) =>
      maxRatePerNight <= 0 || nightlyRate <= maxRatePerNight;

  /// Check whether a property is on the approved list (empty = all approved).
  bool isPropertyApproved(String propertyCode) =>
      approvedPropertyCodes.isEmpty ||
      approvedPropertyCodes.contains(propertyCode);
}

// ═══════════════════════════════════════════════════════════════════════════
// Company Profile (billing + policies + approved properties)
// ═══════════════════════════════════════════════════════════════════════════

class ApprovedProperty {
  final String propertyCode;
  final String propertyName;
  final String city;
  final String? negotiatedRatePlan;
  final double? startingRate;

  const ApprovedProperty({
    required this.propertyCode,
    required this.propertyName,
    required this.city,
    this.negotiatedRatePlan,
    this.startingRate,
  });

  factory ApprovedProperty.fromJson(Map<String, dynamic> json) =>
      ApprovedProperty(
        propertyCode: json['property_code'] as String,
        propertyName: json['property_name'] as String? ?? '',
        city: json['city'] as String? ?? '',
        negotiatedRatePlan: json['negotiated_rate_plan'] as String?,
        startingRate: (json['starting_rate'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
    'property_code': propertyCode,
    'property_name': propertyName,
    'city': city,
    'negotiated_rate_plan': negotiatedRatePlan,
    'starting_rate': startingRate,
  };
}

class CostCenter {
  final String code;
  final String name;
  final String? department;

  const CostCenter({required this.code, required this.name, this.department});

  factory CostCenter.fromJson(Map<String, dynamic> json) => CostCenter(
    code: json['code'] as String,
    name: json['name'] as String,
    department: json['department'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'department': department,
  };
}

class CompanyProfile {
  final String companyId;
  final String companyName;
  final String companyCode;
  final Address billingAddress;
  final String? billingContactName;
  final String? billingContactEmail;
  final String? billingContactPhone;
  final String? taxId;
  final PaymentMethod defaultPaymentMethod;
  final String? paymentTerms;
  final List<TravelPolicy> travelPolicies;
  final List<ApprovedProperty> approvedProperties;
  final List<CostCenter> costCenters;
  final String currencyCode;

  const CompanyProfile({
    required this.companyId,
    required this.companyName,
    required this.companyCode,
    required this.billingAddress,
    this.billingContactName,
    this.billingContactEmail,
    this.billingContactPhone,
    this.taxId,
    this.defaultPaymentMethod = PaymentMethod.creditCard,
    this.paymentTerms,
    this.travelPolicies = const [],
    this.approvedProperties = const [],
    this.costCenters = const [],
    this.currencyCode = 'USD',
  });

  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    return CompanyProfile(
      companyId: json['company_id'] as String,
      companyName: json['company_name'] as String? ?? '',
      companyCode: json['company_code'] as String? ?? '',
      billingAddress: Address.fromJson(
        json['billing_address'] as Map<String, dynamic>? ?? const {},
      ),
      billingContactName: json['billing_contact_name'] as String?,
      billingContactEmail: json['billing_contact_email'] as String?,
      billingContactPhone: json['billing_contact_phone'] as String?,
      taxId: json['tax_id'] as String?,
      defaultPaymentMethod: PaymentMethodX.fromString(
        json['default_payment_method'] as String?,
      ),
      paymentTerms: json['payment_terms'] as String?,
      travelPolicies:
          (json['travel_policies'] as List<dynamic>?)
              ?.map((e) => TravelPolicy.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      approvedProperties:
          (json['approved_properties'] as List<dynamic>?)
              ?.map((e) => ApprovedProperty.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      costCenters:
          (json['cost_centers'] as List<dynamic>?)
              ?.map((e) => CostCenter.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      currencyCode: json['currency_code'] as String? ?? 'USD',
    );
  }

  Map<String, dynamic> toJson() => {
    'company_id': companyId,
    'company_name': companyName,
    'company_code': companyCode,
    'billing_address': billingAddress.toJson(),
    'billing_contact_name': billingContactName,
    'billing_contact_email': billingContactEmail,
    'billing_contact_phone': billingContactPhone,
    'tax_id': taxId,
    'default_payment_method': defaultPaymentMethod.apiValue,
    'payment_terms': paymentTerms,
    'travel_policies': travelPolicies.map((p) => p.toJson()).toList(),
    'approved_properties': approvedProperties.map((p) => p.toJson()).toList(),
    'cost_centers': costCenters.map((c) => c.toJson()).toList(),
    'currency_code': currencyCode,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// Search Request / Result
// ═══════════════════════════════════════════════════════════════════════════

class CorporateSearchRequest {
  final String? destination;
  final String? propertyCode;
  final DateTime arrivalDate;
  final DateTime departureDate;
  final int numberOfRooms;
  final int numberOfGuests;
  final String? travelerId;
  final String? companyCode;

  const CorporateSearchRequest({
    this.destination,
    this.propertyCode,
    required this.arrivalDate,
    required this.departureDate,
    this.numberOfRooms = 1,
    this.numberOfGuests = 1,
    this.travelerId,
    this.companyCode,
  });

  Map<String, dynamic> toJson() => {
    'destination': destination,
    'property_code': propertyCode,
    'arrival_date': _dateStr(arrivalDate),
    'departure_date': _dateStr(departureDate),
    'number_of_rooms': numberOfRooms,
    'number_of_guests': numberOfGuests,
    'traveler_id': travelerId,
    'company_code': companyCode,
  };
}

/// Aggregate search result combining a [CorporateRate] with policy compliance
/// information for the currently authenticated company / traveler.
class SearchResult {
  final CorporateRate rate;
  final bool policyCompliant;
  final String? policyViolationReason;

  const SearchResult({
    required this.rate,
    this.policyCompliant = true,
    this.policyViolationReason,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// Reports
// ═══════════════════════════════════════════════════════════════════════════

class ReportSummary {
  final int totalBookings;
  final int totalRoomNights;
  final double totalSpend;
  final double averageRate;
  final double totalSavings;
  final double policyComplianceRate;
  final String currencyCode;

  const ReportSummary({
    this.totalBookings = 0,
    this.totalRoomNights = 0,
    this.totalSpend = 0,
    this.averageRate = 0,
    this.totalSavings = 0,
    this.policyComplianceRate = 0,
    this.currencyCode = 'USD',
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) => ReportSummary(
    totalBookings: (json['total_bookings'] as num?)?.toInt() ?? 0,
    totalRoomNights: (json['total_room_nights'] as num?)?.toInt() ?? 0,
    totalSpend: (json['total_spend'] as num?)?.toDouble() ?? 0,
    averageRate: (json['average_rate'] as num?)?.toDouble() ?? 0,
    totalSavings: (json['total_savings'] as num?)?.toDouble() ?? 0,
    policyComplianceRate:
        (json['policy_compliance_rate'] as num?)?.toDouble() ?? 0,
    currencyCode: json['currency_code'] as String? ?? 'USD',
  );
}

class ReportByProperty {
  final String propertyCode;
  final String propertyName;
  final int bookingCount;
  final int roomNights;
  final double totalSpend;
  final double totalSavings;

  const ReportByProperty({
    required this.propertyCode,
    required this.propertyName,
    this.bookingCount = 0,
    this.roomNights = 0,
    this.totalSpend = 0,
    this.totalSavings = 0,
  });

  factory ReportByProperty.fromJson(Map<String, dynamic> json) =>
      ReportByProperty(
        propertyCode: json['property_code'] as String,
        propertyName: json['property_name'] as String? ?? '',
        bookingCount: (json['booking_count'] as num?)?.toInt() ?? 0,
        roomNights: (json['room_nights'] as num?)?.toInt() ?? 0,
        totalSpend: (json['total_spend'] as num?)?.toDouble() ?? 0,
        totalSavings: (json['total_savings'] as num?)?.toDouble() ?? 0,
      );
}

class ReportByTraveler {
  final String travelerId;
  final String travelerName;
  final int bookingCount;
  final double totalSpend;
  final double totalSavings;

  const ReportByTraveler({
    required this.travelerId,
    required this.travelerName,
    this.bookingCount = 0,
    this.totalSpend = 0,
    this.totalSavings = 0,
  });

  factory ReportByTraveler.fromJson(Map<String, dynamic> json) =>
      ReportByTraveler(
        travelerId: json['traveler_id'] as String,
        travelerName: json['traveler_name'] as String? ?? '',
        bookingCount: (json['booking_count'] as num?)?.toInt() ?? 0,
        totalSpend: (json['total_spend'] as num?)?.toDouble() ?? 0,
        totalSavings: (json['total_savings'] as num?)?.toDouble() ?? 0,
      );
}

class ReportByMonth {
  final String month;
  final int bookingCount;
  final double totalSpend;
  final double totalSavings;

  const ReportByMonth({
    required this.month,
    this.bookingCount = 0,
    this.totalSpend = 0,
    this.totalSavings = 0,
  });

  factory ReportByMonth.fromJson(Map<String, dynamic> json) => ReportByMonth(
    month: json['month'] as String,
    bookingCount: (json['booking_count'] as num?)?.toInt() ?? 0,
    totalSpend: (json['total_spend'] as num?)?.toDouble() ?? 0,
    totalSavings: (json['total_savings'] as num?)?.toDouble() ?? 0,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Announcement
// ═══════════════════════════════════════════════════════════════════════════

class Announcement {
  final String id;
  final String title;
  final String body;
  final DateTime publishedAt;
  final String? category;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.publishedAt,
    this.category,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String? ?? '',
    publishedAt:
        DateTime.tryParse(json['published_at'] as String? ?? '') ??
        DateTime.now(),
    category: json['category'] as String?,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A credit-approved payment method on the company account (PMS corporate
/// surface). `approval` is `POSTPAY` or `BILL_TO_COMPANY` for the methods
/// checkout can bill (the caller filters approved-only server-side).
class CreditMethod {
  final String id;
  final String label;
  final String? paymentMethodId;
  final String approval;
  final double? creditLimit;

  const CreditMethod({
    required this.id,
    required this.label,
    this.paymentMethodId,
    required this.approval,
    this.creditLimit,
  });

  factory CreditMethod.fromJson(Map<String, dynamic> json) => CreditMethod(
    id: json['id'] as String,
    label: json['label'] as String? ?? '',
    paymentMethodId: json['payment_method_id'] as String?,
    approval: json['approval'] as String? ?? 'PENDING',
    creditLimit:
        double.tryParse(json['credit_limit'] as String? ?? '') ??
        (json['credit_limit'] as num?)?.toDouble(),
  );
}

/// A company the signed-in traveler is bound to (`pms.company_users` row) —
/// the multi-company session switcher's option list.
class CompanyBinding {
  final String companyProfileId;
  final String companyName;
  final String roleAtCompany;
  final bool isDefault;

  const CompanyBinding({
    required this.companyProfileId,
    required this.companyName,
    required this.roleAtCompany,
    this.isDefault = false,
  });

  factory CompanyBinding.fromJson(Map<String, dynamic> json) => CompanyBinding(
    companyProfileId: json['company_profile_id'] as String,
    companyName: json['company_name'] as String? ?? '',
    roleAtCompany: json['role_at_company'] as String? ?? 'TRAVELER',
    isDefault: json['is_default'] as bool? ?? false,
  );
}
