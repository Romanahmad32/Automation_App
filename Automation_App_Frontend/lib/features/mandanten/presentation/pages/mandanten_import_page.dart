import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/seiten_app_bar.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_import_cubit/mandanten_import_cubit.dart';
import 'package:automation_app/features/mandanten/presentation/views/mandanten_import_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Eigene Seite für die Übernahme einer Importdatei (§5.1/§6.1). Sie hängt
/// nicht am `MandantenOverviewBloc`: der Import liest keine Akten und schreibt
/// nur ins Register — den teuren Scan braucht er nicht und würde ihn beim
/// Öffnen nur ein zweites Mal auslösen.
@RoutePage()
class MandantenImportPage extends StatelessWidget implements AutoRouteWrapper {
  const MandantenImportPage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<MandantenImportCubit>(),
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
