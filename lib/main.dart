import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();                                            
  await _loadEnvironment();
  runApp(const BioHelixApp());
}
// dd
Future<void> _loadEnvironment() async { 
  try {
    await dotenv.load(fileName: '.env');
  } catch (error, stackTrace) {
    debugPrint('Skipping .env load: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
