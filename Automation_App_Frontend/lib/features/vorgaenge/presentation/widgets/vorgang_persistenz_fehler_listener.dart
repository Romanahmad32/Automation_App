import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Macht fehlgeschlagene Vorgangs-Persistenz app-weit sichtbar (§7.2): zeigt
/// gemeldete Fehler aus dem [VorgangPersistenzFehlerCubit] über [Rueckmeldung]
/// mit „Erneut versuchen" an. Sitzt in der Shell um den Seiteninhalt, damit
/// die Meldung unabhängig von der gerade offenen Seite erscheint.
class VorgangPersistenzFehlerListener extends StatelessWidget {
  final Widget child;

  const VorgangPersistenzFehlerListener({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<VorgangPersistenzFehlerCubit, VorgangPersistenzFehler?>(
      bloc: getIt<VorgangPersistenzFehlerCubit>(),
      listenWhen: (previous, current) => current != null,
      listener: (context, fehler) {
        Rueckmeldung.von(context).fehler(
          fehler!.meldung,
          aktion: RueckmeldungsAktion(
            text: 'Erneut versuchen',
            beiDruck: () => getIt<VorgangCubit>().wiederhole(fehler),
          ),
        );
        getIt<VorgangPersistenzFehlerCubit>().quittiere();
      },
      child: child,
    );
  }
}
