import 'package:intl/intl.dart';

/// Money class untuk menghindari floating point errors
/// Menyimpan nilai dalam cents/sen (integer) untuk presisi sempurna
class Money {
  final int _cents; // Store as smallest unit (cents/sen)

  Money(double amount) : _cents = (amount * 100).round();
  Money.fromCents(this._cents);
  Money.zero() : _cents = 0;

  double get amount => _cents / 100.0;
  int get cents => _cents;

  // Arithmetic operations
  Money operator +(Money other) => Money.fromCents(_cents + other._cents);
  Money operator -(Money other) => Money.fromCents(_cents - other._cents);
  Money operator *(int multiplier) => Money.fromCents(_cents * multiplier);
  Money operator /(int divisor) => Money.fromCents(_cents ~/ divisor);

  // Comparison
  bool operator >(Money other) => _cents > other._cents;
  bool operator <(Money other) => _cents < other._cents;
  bool operator >=(Money other) => _cents >= other._cents;
  bool operator <=(Money other) => _cents <= other._cents;

  @override
  bool operator ==(Object other) => other is Money && _cents == other._cents;

  @override
  int get hashCode => _cents.hashCode;

  // Percentage calculation
  Money percentage(double percent) {
    return Money.fromCents((_cents * percent / 100).round());
  }

  // Format for display
  String format({String symbol = 'Rp ', int decimalDigits = 0}) {
    return NumberFormat.currency(
      locale: 'id',
      symbol: symbol,
      decimalDigits: decimalDigits,
    ).format(amount);
  }

  @override
  String toString() => format();

  // JSON serialization
  Map<String, dynamic> toJson() => {'cents': _cents};
  factory Money.fromJson(Map<String, dynamic> json) =>
      Money.fromCents(json['cents'] as int);
}
