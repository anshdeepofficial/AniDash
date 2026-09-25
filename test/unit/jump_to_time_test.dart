import 'package:flutter_test/flutter_test.dart';
import 'package:ani_dash/features/watch/view/widgets/player/dialogs/jump_to_time_dialog.dart';

void main() {
  group('JumpToTime Input Parsing & Formatter Tests', () {
    test('Parses raw digit buffer 607 as 6m 7s (367 seconds)', () {
      final res = parseJumpTimeInput('607');
      expect(res, isNotNull);
      expect(res!.inMinutes, 6);
      expect(res.inSeconds, 367);
    });

    test('Parses raw digit buffer 0607 as 6m 7s (367 seconds)', () {
      final res = parseJumpTimeInput('0607');
      expect(res, isNotNull);
      expect(res!.inMinutes, 6);
      expect(res.inSeconds, 367);
    });

    test('Parses formatted 06:07 and 6:07 as 6m 7s (367 seconds)', () {
      final res1 = parseJumpTimeInput('06:07');
      expect(res1, isNotNull);
      expect(res1!.inSeconds, 367);

      final res2 = parseJumpTimeInput('6:07');
      expect(res2, isNotNull);
      expect(res2!.inSeconds, 367);
    });

    test('Parses 1234 as 12m 34s (754 seconds)', () {
      final res = parseJumpTimeInput('1234');
      expect(res, isNotNull);
      expect(res!.inMinutes, 12);
      expect(res.inSeconds, 754);
    });

    test('Parses 0159 as 1m 59s (119 seconds)', () {
      final res = parseJumpTimeInput('0159');
      expect(res, isNotNull);
      expect(res!.inMinutes, 1);
      expect(res.inSeconds, 119);
    });

    test('Rejects invalid seconds (> 59) and invokes error callback', () {
      String? errorMessage;
      final res = parseJumpTimeInput('675', onError: (err) => errorMessage = err);
      expect(res, isNull);
      expect(errorMessage, contains('Seconds must be between 00 and 59'));
    });

    test('TimeDigitInputFormatter formats typing sequence 0 -> 06 -> 06:0 -> 06:07', () {
      final formatter = TimeDigitInputFormatter();

      var val = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '0'),
      );
      expect(val.text, '0');

      val = formatter.formatEditUpdate(
        val,
        const TextEditingValue(text: '06'),
      );
      expect(val.text, '06');

      val = formatter.formatEditUpdate(
        val,
        const TextEditingValue(text: '060'),
      );
      expect(val.text, '06:0');

      val = formatter.formatEditUpdate(
        val,
        const TextEditingValue(text: '0607'),
      );
      expect(val.text, '06:07');
    });

    test('TimeDigitInputFormatter normalizes typing sequence 6 -> 60 -> 6:07', () {
      final formatter = TimeDigitInputFormatter();

      var val = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '6'),
      );
      expect(val.text, '6');

      val = formatter.formatEditUpdate(
        val,
        const TextEditingValue(text: '60'),
      );
      expect(val.text, '60');

      val = formatter.formatEditUpdate(
        val,
        const TextEditingValue(text: '607'),
      );
      expect(val.text, '6:07');
    });

    test('TimeDigitInputFormatter formats 1234 -> 12:34 and 0159 -> 01:59', () {
      final formatter = TimeDigitInputFormatter();

      final val1 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '1234'),
      );
      expect(val1.text, '12:34');

      final val2 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '0159'),
      );
      expect(val2.text, '01:59');
    });
  });
}
