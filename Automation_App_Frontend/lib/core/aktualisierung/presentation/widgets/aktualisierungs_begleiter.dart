import 'dart:async';

import 'package:automation_app/core/aktualisierung/domain/entities/letzte_aktualisierung.dart';
import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierung_cubit.dart';
import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierungs_ansicht.dart';
import 'package:automation_app/core/aktualisierung/presentation/widgets/aktualisierungs_dialog.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// Begleitet die Aktualisierung über die ganze Sitzung (#196) — sitzt in der
/// Shell um alles herum:
///
/// - stößt beim ersten Aufbau die Prüfung an (`AktualisierungCubit.beimStart`),
/// - meldet nach einem Neustart, ob die Aktualisierung geklappt hat (3b/3c),
///   und quittiert das danach beim Dienst — sonst stünde die Meldung bei
///   jedem Start wieder da,
/// - zeigt jede Ablehnung des Dienstes als Fehler-Rückmeldung, auch wenn der
///   Dialog schon zu ist (etwa wenn die Abfrage während des Ladens abreißt).
///
/// Ohne registrierten Cubit (Widget-Tests ohne DI) reicht er nur durch.
class AktualisierungsBegleiter extends StatefulWidget {
  const AktualisierungsBegleiter({required this.child, this.cubit, super.key});

  final Widget child;

  /// Im Test vorgegeben; sonst der app-weite aus `getIt`.
  final AktualisierungCubit? cubit;

  /// 3b bleibt länger stehen als die üblichen drei Sekunden: Nach einer
  /// Minute Warten schaut der Anwalt vielleicht gerade nicht hin.
  static const Duration erfolgDauer = Duration(seconds: 10);

  static String erfolgText(LetzteAktualisierung letzte) =>
      'Die App wurde auf Version ${letzte.zielVersion} aktualisiert.';

  static String fehlerText(LetzteAktualisierung letzte) =>
      'Die Aktualisierung auf Version ${letzte.zielVersion} hat nicht '
      'geklappt. Ihre Daten sind unverändert.';

  @override
  State<AktualisierungsBegleiter> createState() =>
      _AktualisierungsBegleiterState();
}

class _AktualisierungsBegleiterState extends State<AktualisierungsBegleiter> {
  AktualisierungCubit? _cubit;

  @override
  void initState() {
    super.initState();
    _cubit =
        widget.cubit ??
        (getIt.isRegistered<AktualisierungCubit>()
            ? getIt<AktualisierungCubit>()
            : null);
    final cubit = _cubit;
    if (cubit != null) unawaited(cubit.beimStart());
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    if (cubit == null) return widget.child;
    return MultiBlocListener(
      listeners: [
        BlocListener<AktualisierungCubit, AktualisierungsAnsicht>(
          bloc: cubit,
          listenWhen: (alt, neu) =>
              alt.stand?.letzteAktualisierung == null &&
              neu.stand?.letzteAktualisierung != null,
          listener: (context, ansicht) =>
              _meldeErgebnis(ansicht.stand!.letzteAktualisierung!, cubit),
        ),
        BlocListener<AktualisierungCubit, AktualisierungsAnsicht>(
          bloc: cubit,
          listenWhen: (alt, neu) => neu.ablehnung != null,
          listener: (context, ansicht) =>
              Rueckmeldung.zeigeFehler(context, ansicht.ablehnung!),
        ),
      ],
      child: widget.child,
    );
  }

  void _meldeErgebnis(LetzteAktualisierung letzte, AktualisierungCubit cubit) {
    final rueckmeldung = Rueckmeldung.von(context);
    if (letzte.erfolgreich) {
      rueckmeldung.erfolg(
        AktualisierungsBegleiter.erfolgText(letzte),
        dauer: AktualisierungsBegleiter.erfolgDauer,
      );
    } else {
      rueckmeldung.fehler(
        AktualisierungsBegleiter.fehlerText(letzte),
        aktion: RueckmeldungsAktion(
          text: 'Erneut versuchen',
          beiDruck: _erneutVersuchen,
          schluessel: AktualisierungsDialog.erneutVersuchenSchluessel,
        ),
      );
    }
    unawaited(cubit.ergebnisQuittieren());
  }

  /// „Erneut versuchen“ aus 3c: Dialog auf und gleich neu laden (2b).
  void _erneutVersuchen() {
    if (!mounted) return;
    unawaited(
      AktualisierungsDialog.zeigen(
        context,
        erneutVersuchen: true,
        cubit: _cubit,
      ),
    );
  }
}
