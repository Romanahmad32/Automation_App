import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/seiten_app_bar.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_import_cubit/mandanten_import_cubit.dart';
import 'package:automation_app/features/mandanten/presentation/views/mandanten_import_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Eigene Seite für die Übernahme einer Importdatei (§5.1/§6.1). Sie hängt
/// nicht am `MandantenOverviewBloc`, sondern an einem eigenen Cubit: der
/// Zuordnungsstapel bringt Filter, Auswahl und Massenaktionen mit, von denen
/// hier keine gebraucht wird, und sein Zustand würde beim Zurückkehren
/// mitsamt Scrollstand verworfen.
///
/// Den Akten-Scan braucht der Import trotzdem — aber nicht, um zu schreiben,
/// sondern um zu **prüfen**: Ordnernamen in der Datei, die es unter dem
/// Stammordner nicht gibt, halten die Übernahme auf ([MandantenImportCubit.umfeldLaden]).
@RoutePage()
class MandantenImportPage extends StatelessWidget implements AutoRouteWrapper {
  /// Eine schon zusammengestellte Datei statt einer Dateiauswahl — der Weg,
  /// auf dem der Zuordnungsstapel seine sicheren Treffer hereinreicht. Sie
  /// läuft danach durch dieselbe Vorschau wie jede Datei von der Platte.
  final MandantenImportDatei? vorgabe;

  /// Was anstelle eines Dateipfads über der Vorschau steht, z. B. „Sichere
  /// Treffer aus 380 Ordnern". Ohne [vorgabe] ohne Bedeutung.
  final String herkunft;

  const MandantenImportPage({super.key, this.vorgabe, this.herkunft = ''});

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = getIt<MandantenImportCubit>();
        // Beides läuft neben dem Aufbau der Seite und wird bewusst nicht
        // abgewartet: die Dateiauswahl ist ohne Scan bedienbar, und `create`
        // darf nicht blockieren. Genau einmal ausgeführt, weil `create` genau
        // einmal läuft — ein Listener im Widget täte es bei jedem Aufbau neu.
        unawaited(cubit.umfeldLaden());
        final datei = vorgabe;
        if (datei != null) {
          unawaited(cubit.uebernimmDatei(datei, herkunft: herkunft));
        }
        return cubit;
      },
      child: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SeitenAppBar(
        titel: 'Mandanten importieren',
        icon: Icons.file_upload_outlined,
        untertitel: 'Zuordnung aus einer Datei prüfen und übernehmen',
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: BlocBuilder<MandantenImportCubit, MandantenImportState>(
          builder: (context, state) => MandantenImportView(state: state),
        ),
      ),
    );
  }
}
