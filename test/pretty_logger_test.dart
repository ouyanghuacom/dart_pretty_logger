import 'package:flutter_test/flutter_test.dart';

import 'package:pretty_logger/pretty_logger.dart';

void main() {
  test(
    'adds one to input values',
    () async {
      Logger.shared.v('network', 'network message');
      await Future.delayed(Duration(seconds: 120));
    },
    timeout: Timeout(Duration(seconds: 120)),
  );
}
