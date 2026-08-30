import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/router/app_router.gr.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der Weg vom Zuordnungsstapel zum Import. Er steht dort und nicht in den
/// Einstellungen, weil er dieselbe Frage beantwortet wie der Stapel selbst —
/// nur für viertausend Ordner auf einmal statt für einen.
class ImportOeffnenButton extends StatelessWidget {
  const ImportOeffnenButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton.icon(
        onPressed: () => _oeffnen(context),
        icon: const Icon(Icons.file_upload_outlined, size: 18),
        label: const Text('Aus Datei übernehmen'),
      ),
    );
  }

  Future<void> _oeffnen(BuildContext context) async {
    final bloc = context.read<MandantenOverviewBloc>();
    await context.router.push(const MandantenImportRoute());
    // Der Import ändert Register und Vermerke, am Dateisystem aber nichts —
    // der teure Akten-Scan bleibt deshalb stehen.
    bloc.add(const LoadMandantenUebersichtEvent(nurRegister: true));
  }
}
