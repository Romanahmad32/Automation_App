import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mailbox/domain/services/vorgangsbezug_erkenner.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/versicherer/presentation/blocs/versicherer_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';

/// Sammelt zusammen, woraus der [VorgangsbezugErkenner] seinen Schluss zieht
/// (Issue #134): den Vorgangsbestand, die Adressen der Mandanten und die der
/// Versicherer.
///
/// Zwei davon liegen als app-weite Singletons bereit ([VorgangCubit],
/// [VersichererCubit]) und sind jederzeit frisch abzufragen. Die
/// Mandantenadressen dagegen stehen hinter einem Anwendungsfall, der das
/// Register liest — deshalb werden sie **einmal** geholt und hier gehalten:
/// Der Erkenner läuft nach jeder Seitenladung und bei jeder Änderung am
/// Vorgangsbestand, und jedes Mal das Mandantenregister nachzuschlagen wäre
/// ein Datenbankgang für eine Auskunft, die sich zwischendurch nicht ändert.
///
/// Eigener Baustein statt einer Methode in `posteingang_view.dart`: Der Bau
/// des Erkenners ist die einzige Stelle, an der die Ansicht drei fremde
/// Bestände anfasst, und sie soll dafür nicht drei weitere Importe tragen.
class PosteingangBezugQuelle {
  Map<int, String> _mandantenAdressen = const {};

  /// Holt die Mandantenadressen nach. Ein Fehlschlag bleibt still: Ohne sie
  /// entfällt nur die schwächste Erkennungsstufe („Absender ist der
  /// Mandant"), Zeichen und Schadennummer im Betreff tragen weiter.
  Future<void> ladeMandanten() async {
    if (!getIt.isRegistered<UseCase<List<Mandant>, NoParams>>()) return;
    final ergebnis = await getIt<UseCase<List<Mandant>, NoParams>>()(
      const NoParams(),
    );
    switch (ergebnis) {
      case Right(value: final mandanten):
        _mandantenAdressen = {
          for (final mandant in mandanten)
            if (mandant.emailAdresse.trim().isNotEmpty)
              mandant.id: mandant.emailAdresse,
        };
      case Left():
        break;
    }
  }

  /// Der Erkenner mit dem Stand von jetzt.
  VorgangsbezugErkenner erkenner() => VorgangsbezugErkenner(
    vorgaenge: getIt<VorgangCubit>().state,
    mandantenAdressen: _mandantenAdressen,
    versichererAdressen: _versichererAdressen(),
  );

  /// Die Wissensbasis ist ein Komfort, kein Pflichtbestandteil (siehe
  /// [VersichererCubit]) — ist sie nicht eingerichtet, entfällt nur die
  /// Vermutung „Absender ist der Versicherer".
  Map<String, String> _versichererAdressen() {
    if (!getIt.isRegistered<VersichererCubit>()) return const {};
    return {
      for (final versicherer in getIt<VersichererCubit>().state)
        if ((versicherer.email ?? '').trim().isNotEmpty)
          versicherer.name: versicherer.email!,
    };
  }
}
