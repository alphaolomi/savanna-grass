import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import 'ai/gemma_runtime.dart';
import 'api/savanna_api.dart';
import 'app_state.dart';
import 'config.dart';
import 'storage.dart';
import 'ui/home_screen.dart';
import 'ui/login_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterGemma.initialize(
    huggingFaceToken: Config.hfToken.isEmpty ? null : Config.hfToken,
  );
  final state = AppState(
    api: SavannaApi(baseUrl: Config.apiUrl),
    storage: Storage(),
    gemma: GemmaRuntime(),
  );
  runApp(SavannaGrassApp(state: state));
  await state.boot();
}

class SavannaGrassApp extends StatelessWidget {
  const SavannaGrassApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Savanna Grass',
      debugShowCheckedModeBanner: false,
      theme: savannaTheme(Brightness.light),
      darkTheme: savannaTheme(Brightness.dark),
      home: ListenableBuilder(
        listenable: state,
        builder: (context, _) => switch (state.auth) {
          AuthStatus.unknown => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          AuthStatus.signedOut => LoginScreen(state: state),
          AuthStatus.signedIn => HomeScreen(state: state),
        },
      ),
    );
  }
}
