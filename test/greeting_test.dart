import 'package:flutter_test/flutter_test.dart';
import 'package:savanna_grass/ui/home_screen.dart';

void main() {
  test('the name sits inside the late-night question, not after it', () {
    expect(greeting(1, 'Amani'), 'Still up, Amani?');
    expect(greeting(1, null), 'Still up?');
  });

  test('the rest of the day appends the name', () {
    expect(greeting(9, 'Amani'), 'Good morning, Amani');
    expect(greeting(14, null), 'Good afternoon');
    expect(greeting(20, ''), 'Good evening');
  });
}
