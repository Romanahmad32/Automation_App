import 'package:automation_app/core/backend/app_bootstrap.dart';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Der lokale Dienst gehört zur Anwendung: [AppBootstrap] startet ihn, wartet
  // auf seine Bereitschaft und baut erst dann [MyApp] — inklusive der
  // Dependency Injection, die ohne den Dienst nichts zu tun hätte.
  runApp(AppBootstrap(anwendungBauen: MyApp.new));
}

class MyApp extends StatelessWidget {
  final _router = getIt<AppRouter>();

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => getIt<ThemeBloc>()..add(LoadThemeEvent()),
        ),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, state) {
          // Das Theme entsteht **im** Builder, nicht davor: Seit Issue #57
          // die Schriftgröße wählbar macht, hängt nicht mehr nur die Auswahl
          // zwischen zwei fertigen Themes am Zustand, sondern die Skala, aus
          // der sie gebaut werden. Zwei vorab gebaute Objekte trügen für
          // immer die Stufe, die beim ersten Bild galt — der Anwalt stellte
          // um und nichts geschähe. Gebaut wird nur die aktive Familie; die
          // andere kostet hier nichts.
          final MaterialTheme theme = state.variant == AppThemeVariant.kanzlei
              ? KanzleiMaterialTheme(
                  createKanzleiTextTheme(context),
                  schriftstufe: state.schriftstufe,
                )
              : MaterialTheme(
                  createTextTheme(context, 'Inter', 'Inter'),
                  schriftstufe: state.schriftstufe,
                );
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
