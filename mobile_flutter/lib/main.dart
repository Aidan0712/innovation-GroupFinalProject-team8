import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/services/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.instance.init();
  runApp(const AiInterviewApp());
}
