import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/shell.dart';
import 'screens/splash.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();
  runApp(ParcelboniaApp(store: Store(prefs)));
}

class ParcelboniaApp extends StatefulWidget {
  final Store store;
  const ParcelboniaApp({super.key, required this.store});
  @override
  State<ParcelboniaApp> createState() => _ParcelboniaAppState();
}

class _ParcelboniaAppState extends State<ParcelboniaApp> with WidgetsBindingObserver {
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Mobile OSes drop open sockets in the background; reconnect on return.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.store.resume();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return StoreScope(
      store: store,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final dark = store.dark;
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            statusBarBrightness: dark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
            systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          ));

          final Widget home;
          if (!_splashDone) {
            home = SplashScreen(
              key: const ValueKey('splash'),
              boot: store.boot,
              onDone: () => setState(() => _splashDone = true),
            );
          } else {
            home = const Shell(key: ValueKey('shell'));
          }

          return MaterialApp(
            title: 'Parcelbonia',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(dark),
            // Respect the user's font size, but cap it so layouts never break.
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: .85, maxScaleFactor: 1.25)),
                child: child!,
              );
            },
            home: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              switchInCurve: Curves.easeOut,
              child: home,
            ),
          );
        },
      ),
    );
  }
}
