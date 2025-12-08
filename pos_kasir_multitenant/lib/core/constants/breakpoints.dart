class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 800;
  static const double desktop = 1200;

  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= tablet && width < desktop;
  static bool isDesktop(double width) => width >= desktop;
  static bool isTabletOrLarger(double width) => width >= tablet;
}
