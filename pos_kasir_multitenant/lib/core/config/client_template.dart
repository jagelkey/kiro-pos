// CLIENT CONFIGURATION TEMPLATE
// This file will be customized for each client
// DO NOT EDIT MANUALLY - Use setup wizard instead

class ClientConfig {
  // ============================================
  // CLIENT INFORMATION
  // ============================================

  static const String clientName = '{{CLIENT_NAME}}';
  static const String businessType = '{{BUSINESS_TYPE}}';
  static const String setupDate = '{{SETUP_DATE}}';
  static const String package = '{{PACKAGE}}';

  // ============================================
  // SUPABASE CONFIGURATION
  // ============================================

  static const String supabaseUrl = '{{SUPABASE_URL}}';
  static const String supabaseAnonKey = '{{SUPABASE_ANON_KEY}}';

  // ============================================
  // TENANT INFORMATION
  // ============================================

  static const String tenantId = '{{TENANT_ID}}';
  static const String tenantIdentifier = '{{TENANT_IDENTIFIER}}';

  // ============================================
  // BRANDING CONFIGURATION
  // ============================================

  static const String primaryColorHex = '{{PRIMARY_COLOR}}';
  static const String secondaryColorHex = '{{SECONDARY_COLOR}}';
  static const String logoPath = '{{LOGO_PATH}}';

  // ============================================
  // APP CONFIGURATION
  // ============================================

  static const String appName = '{{APP_NAME}}';
  static const String appVersion = '{{APP_VERSION}}';
  static const String packageName = '{{PACKAGE_NAME}}';

  // ============================================
  // SUPPORT INFORMATION
  // ============================================

  static const String supportWhatsApp = '{{SUPPORT_WHATSAPP}}';
  static const String supportEmail = '{{SUPPORT_EMAIL}}';
  static const String supportPeriodEnd = '{{SUPPORT_PERIOD_END}}';

  // ============================================
  // FEATURE FLAGS
  // ============================================

  static const bool enableCustomBranding = {
    {ENABLE_CUSTOM_BRANDING}
  };
  static const bool enableMultiBranch = {
    {ENABLE_MULTI_BRANCH}
  };
  static const bool enableAdvancedReports = {
    {ENABLE_ADVANCED_REPORTS}
  };
  static const bool enableIntegrations = {
    {ENABLE_INTEGRATIONS}
  };

  // ============================================
  // COMPUTED PROPERTIES
  // ============================================

  static int get primaryColor {
    try {
      return int.parse(primaryColorHex.replaceAll('#', '0xFF'));
    } catch (e) {
      return 0xFF2196F3; // Default blue
    }
  }

  static int get secondaryColor {
    try {
      return int.parse(secondaryColorHex.replaceAll('#', '0xFF'));
    } catch (e) {
      return 0xFF03DAC6; // Default teal
    }
  }

  static bool get isTrialExpired {
    try {
      final endDate = DateTime.parse(supportPeriodEnd);
      return DateTime.now().isAfter(endDate);
    } catch (e) {
      return false;
    }
  }

  static int get daysUntilExpiry {
    try {
      final endDate = DateTime.parse(supportPeriodEnd);
      return endDate.difference(DateTime.now()).inDays;
    } catch (e) {
      return 999;
    }
  }
}
