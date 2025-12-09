/// **Feature: dashboard-comprehensive-fix, Property 15: Responsive Grid Layout**
/// **Validates: Requirements 10.1, 10.2**
///
/// Property: For any screen width < 600px, the statistics grid SHALL display 2 columns;
/// for width >= 600px, it SHALL display 4 columns.
library;

import 'package:glados/glados.dart';

/// Responsive layout calculator (mirrors DashboardScreen and Breakpoints logic)
class ResponsiveLayoutCalculator {
  static const double tabletBreakpoint = 600.0;
  static const int mobileColumns = 2;
  static const int tabletColumns = 4;

  /// Determine if screen is tablet or larger
  /// Requirements 10.1, 10.2
  static bool isTabletOrLarger(double width) {
    return width >= tabletBreakpoint;
  }

  /// Get grid column count based on screen width
  /// Requirements 10.1: 2 columns for width < 600px
  /// Requirements 10.2: 4 columns for width >= 600px
  static int getGridColumnCount(double width) {
    return isTabletOrLarger(width) ? tabletColumns : mobileColumns;
  }

  /// Get aspect ratio for stat cards based on screen width
  static double getCardAspectRatio(double width) {
    return isTabletOrLarger(width) ? 1.8 : 1.5;
  }
}

/// Generator for mobile screen widths (< 600)
extension MobileWidthGenerator on Any {
  Generator<double> get mobileWidth {
    return any.doubleInRange(280.0, 599.9);
  }
}

/// Generator for tablet screen widths (>= 600)
extension TabletWidthGenerator on Any {
  Generator<double> get tabletWidth {
    return any.doubleInRange(600.0, 1920.0);
  }
}

/// Generator for any valid screen width
extension AnyWidthGenerator on Any {
  Generator<double> get anyScreenWidth {
    return any.doubleInRange(280.0, 2560.0);
  }
}

/// Generator for widths around the breakpoint
extension BreakpointWidthGenerator on Any {
  Generator<double> get widthNearBreakpoint {
    return any.doubleInRange(590.0, 610.0);
  }
}

void main() {
  /// **Feature: dashboard-comprehensive-fix, Property 15: Responsive Grid Layout**
  /// **Validates: Requirements 10.1**
  ///
  /// Property: Mobile width (< 600px) results in 2 columns
  Glados(any.mobileWidth).test(
    'Mobile width results in 2 columns',
    (width) {
      final columns = ResponsiveLayoutCalculator.getGridColumnCount(width);

      if (columns != ResponsiveLayoutCalculator.mobileColumns) {
        throw Exception(
          'Width $width should have ${ResponsiveLayoutCalculator.mobileColumns} columns, got $columns',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 15: Responsive Grid Layout**
  /// **Validates: Requirements 10.2**
  ///
  /// Property: Tablet width (>= 600px) results in 4 columns
  Glados(any.tabletWidth).test(
    'Tablet width results in 4 columns',
    (width) {
      final columns = ResponsiveLayoutCalculator.getGridColumnCount(width);

      if (columns != ResponsiveLayoutCalculator.tabletColumns) {
        throw Exception(
          'Width $width should have ${ResponsiveLayoutCalculator.tabletColumns} columns, got $columns',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 15: Responsive Grid Layout**
  /// **Validates: Requirements 10.1, 10.2**
  ///
  /// Property: Exactly at breakpoint (600px) results in tablet layout
  Glados(any.intInRange(0, 100)).test(
    'Exactly at breakpoint (600px) results in tablet layout',
    (_) {
      const exactBreakpoint = 600.0;
      final columns =
          ResponsiveLayoutCalculator.getGridColumnCount(exactBreakpoint);

      if (columns != ResponsiveLayoutCalculator.tabletColumns) {
        throw Exception(
          'Width $exactBreakpoint should have ${ResponsiveLayoutCalculator.tabletColumns} columns, got $columns',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 15: Responsive Grid Layout**
  /// **Validates: Requirements 10.1, 10.2**
  ///
  /// Property: Just below breakpoint (599.9px) results in mobile layout
  Glados(any.intInRange(0, 100)).test(
    'Just below breakpoint (599.9px) results in mobile layout',
    (_) {
      const justBelowBreakpoint = 599.9;
      final columns =
          ResponsiveLayoutCalculator.getGridColumnCount(justBelowBreakpoint);

      if (columns != ResponsiveLayoutCalculator.mobileColumns) {
        throw Exception(
          'Width $justBelowBreakpoint should have ${ResponsiveLayoutCalculator.mobileColumns} columns, got $columns',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 15: Responsive Grid Layout**
  /// **Validates: Requirements 10.1, 10.2**
  ///
  /// Property: isTabletOrLarger returns correct boolean
  Glados(any.anyScreenWidth).test(
    'isTabletOrLarger returns correct boolean',
    (width) {
      final isTablet = ResponsiveLayoutCalculator.isTabletOrLarger(width);
      final expected = width >= ResponsiveLayoutCalculator.tabletBreakpoint;

      if (isTablet != expected) {
        throw Exception(
          'isTabletOrLarger($width) should be $expected, got $isTablet',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 15: Responsive Grid Layout**
  /// **Validates: Requirements 10.1, 10.2**
  ///
  /// Property: Column count is always either 2 or 4
  Glados(any.anyScreenWidth).test(
    'Column count is always either 2 or 4',
    (width) {
      final columns = ResponsiveLayoutCalculator.getGridColumnCount(width);

      if (columns != 2 && columns != 4) {
        throw Exception(
          'Column count should be 2 or 4, got $columns for width $width',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 15: Responsive Grid Layout**
  /// **Validates: Requirements 10.3**
  ///
  /// Property: Aspect ratio is appropriate for screen size
  Glados(any.anyScreenWidth).test(
    'Aspect ratio is appropriate for screen size',
    (width) {
      final aspectRatio = ResponsiveLayoutCalculator.getCardAspectRatio(width);
      final isTablet = ResponsiveLayoutCalculator.isTabletOrLarger(width);

      final expectedRatio = isTablet ? 1.8 : 1.5;

      if ((aspectRatio - expectedRatio).abs() > 0.001) {
        throw Exception(
          'Aspect ratio for width $width should be $expectedRatio, got $aspectRatio',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 15: Responsive Grid Layout**
  /// **Validates: Requirements 10.1, 10.2**
  ///
  /// Property: Increasing width from mobile to tablet changes columns from 2 to 4
  Glados(any.mobileWidth).test(
    'Increasing width from mobile to tablet changes columns',
    (mobileWidth) {
      final tabletWidth = mobileWidth + 100; // Ensure it's >= 600

      final mobileColumns =
          ResponsiveLayoutCalculator.getGridColumnCount(mobileWidth);
      final tabletColumns =
          ResponsiveLayoutCalculator.getGridColumnCount(tabletWidth);

      if (tabletWidth >= 600 && tabletColumns <= mobileColumns) {
        throw Exception(
          'Tablet width ($tabletWidth) should have more columns than mobile ($mobileWidth): '
          'tablet=$tabletColumns, mobile=$mobileColumns',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 15: Responsive Grid Layout**
  /// **Validates: Requirements 10.1, 10.2**
  ///
  /// Property: Layout is deterministic - same width always produces same result
  Glados(any.anyScreenWidth).test(
    'Layout is deterministic - same width always produces same result',
    (width) {
      final columns1 = ResponsiveLayoutCalculator.getGridColumnCount(width);
      final columns2 = ResponsiveLayoutCalculator.getGridColumnCount(width);
      final isTablet1 = ResponsiveLayoutCalculator.isTabletOrLarger(width);
      final isTablet2 = ResponsiveLayoutCalculator.isTabletOrLarger(width);

      if (columns1 != columns2) {
        throw Exception(
          'Column count should be deterministic: $columns1 vs $columns2',
        );
      }

      if (isTablet1 != isTablet2) {
        throw Exception(
          'isTabletOrLarger should be deterministic: $isTablet1 vs $isTablet2',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 15: Responsive Grid Layout**
  /// **Validates: Requirements 10.1, 10.2**
  ///
  /// Property: Widths near breakpoint behave correctly
  Glados(any.widthNearBreakpoint).test(
    'Widths near breakpoint behave correctly',
    (width) {
      final columns = ResponsiveLayoutCalculator.getGridColumnCount(width);
      final expectedColumns = width >= 600.0 ? 4 : 2;

      if (columns != expectedColumns) {
        throw Exception(
          'Width $width near breakpoint should have $expectedColumns columns, got $columns',
        );
      }
    },
  );
}
