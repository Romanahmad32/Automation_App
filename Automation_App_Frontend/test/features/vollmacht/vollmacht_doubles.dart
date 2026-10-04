import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_auftrag.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_ergebnis.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorlagen_stand.dart';
import 'package:automation_app/features/vollmacht/domain/repositories/vollmacht_repository.dart';
import 'package:automation_app/features/vollmacht/domain/usecases/drucke_vollmacht.dart';
import 'package:automation_app/features/vollmacht/domain/usecases/fuelle_vollmacht_aus.dart';
import 'package:automation_app/features/vollmacht/domain/usecases/lade_vollmacht_mandant.dart';
import 'package:automation_app/features/vollmacht/domain/usecases/lade_vollmacht_vorlagen.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_cubit.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/vorgang_repository.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler_cubit.dart';

/// Der Dienst der Vollmacht im Speicher: welche Vorlagen da sind, welcher
/// Mandant bekannt ist, wie Druck und Ausfüllen ausgehen — und was bestellt
/// wurde.
class VollmachtRepositoryDouble implements VollmachtRepository {
  VollmachtVorlagenStand vorlagen = standMit(VollmachtArt.values.toSet());
  final Map<int, Mandant> mandanten = {};
  Failure? mandantFehler;

  /// Der Dienst selbst ist nicht erreichbar — nicht zu verwechseln mit einem
  /// Druck, den er meldet, aber Word nicht annahm ([druckErgebnis]).
  Failure? druckFehler;

  VollmachtErgebnis druckErgebnis = const VollmachtErgebnis(
    status: VollmachtErgebnisStatus.gedruckt,
  );
  VollmachtErgebnis ausfuellErgebnis = const VollmachtErgebnis(
    status: VollmachtErgebnisStatus.ausgefuellt,
    pfad: r'C:\Arbeit\Vollmacht Strafsache.docx',
  );

  final List<VollmachtAuftrag> gedruckt = [];
  final List<VollmachtAuftrag> ausgefuellt = [];

  static VollmachtVorlagenStand standMit(Set<VollmachtArt> vorhanden) =>
      VollmachtVorlagenStand(
        ordner: r'C:\Vorlagen\Vollmacht',
        vorlagen: [
          for (final art in VollmachtArt.values)
            VollmachtVorlage(
              art: art,
              dateiname: 'Vollmacht ${art.titel}.docx',
              vorhanden: vorhanden.contains(art),
            ),
        ],
      );

  @override
  Future<Either<Failure, VollmachtVorlagenStand>> ladeVorlagen() async =>
      Right(vorlagen);

  @override
  Future<Either<Failure, Mandant?>> ladeMandant(int id) async {
    final fehler = mandantFehler;
    return fehler != null ? Left(fehler) : Right(mandanten[id]);
  }

  @override
  Future<Either<Failure, VollmachtErgebnis>> drucke(
    VollmachtAuftrag auftrag,
  ) async {
    gedruckt.add(auftrag);
    final fehler = druckFehler;
    return fehler != null ? Left(fehler) : Right(druckErgebnis);
  }

  @override
  Future<Either<Failure, VollmachtErgebnis>> fuelleAus(
    VollmachtAuftrag auftrag,
  ) async {
    ausgefuellt.add(auftrag);
    return Right(ausfuellErgebnis);
  }
}

/// Vorgänge im Speicher — gerade genug für den Vermerk der Vollmacht.
class VollmachtVorgaengeDouble implements VorgangRepository {
  final Map<String, Vorgang> bestand = {};
  final List<(String, bool)> vermerke = [];

  @override
  Future<List<Vorgang>> loadVorgaenge() async => bestand.values.toList();

  @override
  Future<Vorgang> upsertVorgang(Vorgang vorgang) async =>
      bestand[vorgang.referenz] = vorgang;

  @override
  Future<void> deleteVorgang(
    String referenz, {
    bool registerzeileBehalten = true,
  }) async => bestand.remove(referenz);

  @override
  Future<Vorgang?> setzeEntwurf(String referenz, VorgangEntwurf? e) async =>
      bestand[referenz];

  @override
  Future<Vorgang?> abschliessenVorgang(String referenz) async =>
      bestand[referenz];

  @override
  Future<Vorgang?> aendereReferenz(String von, String nach) async => null;

  @override
  Future<Vorgang?> setzeVollmachtVermerk(
    String referenz, {
    required bool gedruckt,
  }) async {
    final vorgang = bestand[referenz];
    if (vorgang == null) return null;
    vermerke.add((referenz, gedruckt));
    return bestand[referenz] = vorgang.copyWith(
      vollmachtGedrucktAm: () => gedruckt ? DateTime(2026, 9, 13) : null,
    );
  }
}

/// Baut den Cubit auf den beiden Doubles. [vorgaenge] trägt die Vorgänge, die
/// der app-weite [VorgangCubit] kennen soll.
Future<({VollmachtCubit cubit, VorgangCubit vorgaengeCubit})>
baueVollmachtCubit(
  VollmachtRepositoryDouble dienst,
  VollmachtVorgaengeDouble vorgaenge,
) async {
  final vorgaengeCubit = VorgangCubit(
    vorgaenge,
    VorgangPersistenzFehlerCubit(),
  );
  // Der VorgangCubit lädt im Konstruktor; einmal die Warteschlange leeren.
  await Future<void>.delayed(Duration.zero);
  final cubit = VollmachtCubit(
    LadeVollmachtVorlagen(dienst),
    LadeVollmachtMandant(dienst),
    DruckeVollmacht(dienst),
    FuelleVollmachtAus(dienst),
    vorgaengeCubit,
  );
  return (cubit: cubit, vorgaengeCubit: vorgaengeCubit);
}
