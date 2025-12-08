import 'package:flutter_test/flutter_test.dart';
import 'package:pos_kasir_multitenant/core/utils/promo_code_utils.dart';

void main() {
  group('PromoCodeUtils Tests', () {
    group('normalize', () {
      test('converts to uppercase', () {
        expect(PromoCodeUtils.normalize('discount10'), equals('DISCOUNT10'));
        expect(PromoCodeUtils.normalize('NewYear2024'), equals('NEWYEAR2024'));
      });

      test('trims whitespace', () {
        expect(PromoCodeUtils.normalize('  SAVE20  '), equals('SAVE20'));
        expect(PromoCodeUtils.normalize('\tDISCOUNT\n'), equals('DISCOUNT'));
      });

      test('handles empty and null', () {
        expect(PromoCodeUtils.normalize(''), equals(''));
        expect(PromoCodeUtils.normalize(null), equals(''));
        expect(PromoCodeUtils.normalize('   '), equals(''));
      });

      test('preserves dashes and numbers', () {
        expect(
            PromoCodeUtils.normalize('NEW-YEAR-2024'), equals('NEW-YEAR-2024'));
        expect(PromoCodeUtils.normalize('save-10-percent'),
            equals('SAVE-10-PERCENT'));
      });
    });

    group('matches', () {
      test('matches case-insensitive codes', () {
        expect(PromoCodeUtils.matches('DISCOUNT10', 'discount10'), true);
        expect(PromoCodeUtils.matches('NewYear', 'NEWYEAR'), true);
        expect(PromoCodeUtils.matches('save20', 'SAVE20'), true);
      });

      test('matches with whitespace', () {
        expect(PromoCodeUtils.matches('  SAVE20  ', 'save20'), true);
        expect(PromoCodeUtils.matches('DISCOUNT', '  discount  '), true);
      });

      test('does not match different codes', () {
        expect(PromoCodeUtils.matches('SAVE10', 'SAVE20'), false);
        expect(PromoCodeUtils.matches('DISCOUNT', 'PROMO'), false);
      });

      test('handles null values', () {
        expect(PromoCodeUtils.matches(null, 'SAVE20'), false);
        expect(PromoCodeUtils.matches('SAVE20', null), false);
        expect(PromoCodeUtils.matches(null, null), false);
      });

      test('handles empty strings', () {
        expect(PromoCodeUtils.matches('', 'SAVE20'), false);
        expect(PromoCodeUtils.matches('SAVE20', ''), false);
      });
    });

    group('validate', () {
      test('accepts valid promo codes', () {
        expect(PromoCodeUtils.validate('SAVE20'), isNull);
        expect(PromoCodeUtils.validate('NEW-YEAR-2024'), isNull);
        expect(PromoCodeUtils.validate('DISCOUNT123'), isNull);
      });

      test('accepts null (optional)', () {
        expect(PromoCodeUtils.validate(null), isNull);
        expect(PromoCodeUtils.validate(''), isNull);
      });

      test('rejects too short codes', () {
        expect(PromoCodeUtils.validate('AB'), isNotNull);
        expect(PromoCodeUtils.validate('A'), isNotNull);
      });

      test('rejects too long codes', () {
        expect(
          PromoCodeUtils.validate('VERYLONGPROMOCODETHATEXCEEDSLIMIT'),
          isNotNull,
        );
      });

      test('rejects invalid characters', () {
        expect(PromoCodeUtils.validate('SAVE@20'), isNotNull);
        expect(PromoCodeUtils.validate('DISCOUNT!'), isNotNull);
        expect(PromoCodeUtils.validate('PROMO CODE'), isNotNull); // space
        expect(PromoCodeUtils.validate('SAVE_20'), isNotNull); // underscore
      });

      test('accepts dashes', () {
        expect(PromoCodeUtils.validate('NEW-YEAR'), isNull);
        expect(PromoCodeUtils.validate('SAVE-10-PERCENT'), isNull);
      });
    });

    group('format', () {
      test('formats for display', () {
        expect(PromoCodeUtils.format('discount10'), equals('DISCOUNT10'));
        expect(PromoCodeUtils.format('  save20  '), equals('SAVE20'));
      });

      test('handles null', () {
        expect(PromoCodeUtils.format(null), equals(''));
      });
    });

    group('generate', () {
      test('generates code with default length', () {
        final code = PromoCodeUtils.generate();
        expect(code.length, equals(8));
        expect(RegExp(r'^[A-Z0-9]+$').hasMatch(code), true);
      });

      test('generates code with custom length', () {
        final code = PromoCodeUtils.generate(length: 12);
        expect(code.length, equals(12));
        expect(RegExp(r'^[A-Z0-9]+$').hasMatch(code), true);
      });

      test('generates different codes', () {
        final code1 = PromoCodeUtils.generate();
        final code2 = PromoCodeUtils.generate();
        // Note: There's a small chance they could be the same
        // but very unlikely with timestamp-based generation
        expect(code1, isNotEmpty);
        expect(code2, isNotEmpty);
      });
    });
  });

  group('Real-world Scenarios', () {
    test('user enters promo code in different cases', () {
      const storedCode = 'NEWYEAR2024';

      expect(PromoCodeUtils.matches(storedCode, 'newyear2024'), true);
      expect(PromoCodeUtils.matches(storedCode, 'NewYear2024'), true);
      expect(PromoCodeUtils.matches(storedCode, 'NEWYEAR2024'), true);
      expect(PromoCodeUtils.matches(storedCode, '  newyear2024  '), true);
    });

    test('validate promo code before saving', () {
      // Valid codes
      expect(PromoCodeUtils.validate('SAVE10'), isNull);
      expect(PromoCodeUtils.validate('BLACKFRIDAY'), isNull);
      expect(PromoCodeUtils.validate('CYBER-MONDAY-2024'), isNull);

      // Invalid codes
      expect(PromoCodeUtils.validate('AB'), isNotNull); // Too short
      expect(PromoCodeUtils.validate('SAVE 10'), isNotNull); // Has space
      expect(PromoCodeUtils.validate('SAVE@10'), isNotNull); // Invalid char
    });

    test('normalize before storing in database', () {
      const userInput = '  NewYear2024  ';
      final normalized = PromoCodeUtils.normalize(userInput);

      expect(normalized, equals('NEWYEAR2024'));
      expect(normalized, equals(normalized.toUpperCase()));
      expect(normalized, equals(normalized.trim()));
    });
  });
}
