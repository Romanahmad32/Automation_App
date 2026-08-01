import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/router/app_router.dart';
import 'package:automation_app/core/theme/domain/theme_preferences.dart';
import 'package:automation_app/core/theme/presentation/bloc/theme_bloc.dart';
import 'package:automation_app/core/theme/presentation/kanzlei_theme.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/core/theme/presentation/util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  await getIt.allReady();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final _router = getIt<AppRouter>();

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Standard-Design (blaues Material-Theme) und Kanzlei-Design (Variante A)
    // werden beide aufgebaut; die aktive Familie wählt der ThemeBloc.
    final MaterialTheme standardTheme = MaterialTheme(
      createTextTheme(context, 'Inter', 'Inter'),
    );
    final MaterialTheme kanzleiTheme = KanzleiMaterialTheme(
      createKanzleiTextTheme(context),
    );
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => getIt<ThemeBloc>()..add(LoadThemeEvent()),
        ),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, state) {
          final MaterialTheme theme = state.variant == AppThemeVariant.kanzlei
              ? kanzleiTheme
              : standardTheme;
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            routerConfig: _router.config(),
            themeMode: state.mode,
            darkTheme: theme.dark(),
            theme: theme.light(),
            // Deutsche Texte für Material-Dialoge (z. B. den Datums-Picker).
            locale: const Locale('de'),
            supportedLocales: const [Locale('de')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          );
        },
      ),
    );
  }
}
