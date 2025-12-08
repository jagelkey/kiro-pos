/// Exception untuk shift-related errors
class ShiftException implements Exception {
  final String message;

  ShiftException(this.message);

  @override
  String toString() => message;
}
