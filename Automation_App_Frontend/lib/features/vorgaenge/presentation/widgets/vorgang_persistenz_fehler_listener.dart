import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Macht fehlgeschlagene Vorgangs-Persistenz app-weit sichtbar (Req. 8): zeigt
/// gemeldete Fehler aus dem [VorgangPersistenzFehlerCubit] als Snackbar mit
/// „Erneut versuchen" an. Sitzt in der Shell um den Seiteninhalt, damit die
/// Meldung unabhängig von der gerade offenen Seite erscheint.
class VorgangPersistenzFehlerListener extends StatelessWidget {
  final Widget child;

  const VorgangPersistenzFehlerListener({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<VorgangPersistenzFehlerCubit, VorgangPersistenzFehler?>(
      bloc: getIt<VorgangPersistenzFehlerCubit>(),
      listenWhen: (previous, current) => current != null,
      listener: (context, fehler) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(fehler!.meldung),
            backgroundColor: theme.colorScheme.error,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Erneut versuchen',
              textColor: theme.colorScheme.onError,
              onPressed: () => getIt<VorgangCubit>().wiederhole(fehler),
            ),
          ),
        );
        getIt<VorgangPersistenzFehlerCubit>().quittiere();
      },
      child: child,
    );
  }
}
