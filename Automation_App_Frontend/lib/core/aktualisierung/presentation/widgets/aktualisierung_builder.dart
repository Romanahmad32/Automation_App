import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierung_cubit.dart';
import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierungs_ansicht.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// Stellt den Stand der Aktualisierung zum Bauen bereit — für Seitenleiste,
/// „Über diese Anwendung“ und den Einstellungen-Reiter „Über“.
///
/// Hängt am app-weiten `@lazySingleton`-[AktualisierungCubit] über `getIt`
/// (kein `BlocProvider` — der würde den Cubit beim Verlassen der Seite
/// schließen, und mit ihm das Abfragen während des Ladens). Gefragt wird nicht
/// hier, sondern einmal je Sitzung im `AktualisierungsBegleiter`.
///
/// Ohne registrierten Cubit (Widget-Tests ohne DI) ist die Ansicht `null`; die
/// Oberfläche zeigt dann einfach keinen Hinweis.
class AktualisierungBuilder extends StatelessWidget {
  const AktualisierungBuilder({required this.builder, super.key});

  final Widget Function(BuildContext context, AktualisierungsAnsicht? ansicht)
  builder;

  @override
  Widget build(BuildContext context) {
    if (!getIt.isRegistered<AktualisierungCubit>()) {
      return builder(context, null);
    }
    return BlocBuilder<AktualisierungCubit, AktualisierungsAnsicht>(
      bloc: getIt<AktualisierungCubit>(),
      builder: builder,
    );
  }
}
