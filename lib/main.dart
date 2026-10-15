import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'shared/glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await warmUpGlass();
  runApp(const ProviderScope(child: TrueNasMobileApp()));
}
