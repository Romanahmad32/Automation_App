import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/seiten_app_bar.dart';
import 'package:automation_app/features/register_import/presentation/blocs/register_import_cubit/register_import_cubit.dart';
import 'package:automation_app/features/register_import/presentation/views/register_import_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Eigene Seite für die Übernahme der Registerhistorie (§6.2). Sie wird aus
/// dem Register (Tab 6) geöffnet und hängt an einem eigenen Cubit: Der Import
/// ist ein Vorgang mit Anfang und Ende, die Registeransicht daneben eine
/// Daueransicht — ein gemeinsamer Zustand verlöre beim Zurückkehren Filter und
/// Scrollstand des einen für den anderen.
@RoutePage()
class RegisterImportPage extends StatelessWidget implements AutoRouteWrapper {
  /// Der Jahrgang, den die Anleitung vorschlägt — der Stand auf Tab 6 kennt
  /// den kleinsten fehlenden und reicht ihn hier herein. Ohne Vorgabe wählt
  /// die Anleitung das laufende Jahr minus eins.
  final int? vorgeschlagenerJahrgang;

  const RegisterImportPage({super.key, this.vorgeschlagenerJahrgang});

  @override
  Widget wrappedRoute(BuildContext context) =>
      BlocProvider(create: (_) => getIt<RegisterImportCubit>(), child: this);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SeitenAppBar(
        titel: 'Registerhistorie einlesen',
        icon: Icons.history_edu_outlined,
        untertitel: 'Jahrgang für Jahrgang prüfen und übernehmen',
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: BlocBuilder<RegisterImportCubit, RegisterImportState>(
          builder: (context, state) => RegisterImportView(
            state: state,
            vorgeschlagenerJahrgang: vorgeschlagenerJahrgang,
          ),
        ),
      ),
    );
  }
}
