import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordnernamen_menge.dart';
import 'package:automation_app/features/mandanten/domain/usecases/loese_ordner_von_mandant.dart';
import 'package:automation_app/features/mandanten/domain/usecases/verknuepfe_ordner_mit_mandant.dart';

import 'mandanten_testaufbau.dart';

// Die beiden Attrappen, die einem Mandanten einen Ordner geben oder nehmen —
// neben `mandanten_testaufbau.dart`, weil der sonst an seine Zeilengrenze
// stieße. Beide schreiben in denselben `MandantenSpeicher` wie Seitenabruf
// und Ordnernamen, wie die eine Tabelle im Backend.

/// Verknüpft, indem der Ordner am Mandanten hängend zurückkommt — genau das,
/// was der Bloc in den Zustand fortschreiben soll. Nimmt wie der Dienst den
/// Vermerk „ohne Mandantenbezug" mit zurück.
class FakeVerknuepfen implements UseCase<Mandant, VerknuepfeOrdnerParams> {
  final MandantenSpeicher speicher;
  final OrdnerStatusSpeicher vermerke;

  FakeVerknuepfen(this.speicher, this.vermerke);

  @override
  Future<Either<Failure, Mandant>> call(VerknuepfeOrdnerParams params) async {
    final fehler = speicher.fehlerBeimVerknuepfen;
    if (fehler != null) return Left(LocalFailure(message: fehler));
    final alt = speicher.mandanten.firstWhere((m) => m.id == params.mandantId);
    final neu = mandant(
      alt.id,
      alt.nachname,
      ordner: [...alt.aktenOrdnernamen, params.ordnername],
    );
    speicher.ersetze(neu);
    final zugeordnet = OrdnernamenMenge([params.ordnername]);
    vermerke.eintraege.removeWhere((name, _) => zugeordnet.enthaelt(name));
    return Right(neu);
  }
}

/// Löst, indem der Mandant ohne den Ordner zurückkommt — gleich in welcher
/// Schreibweise er dort steht, wie der Dienst.
class FakeLoesen implements UseCase<Mandant, LoeseOrdnerParams> {
  final MandantenSpeicher speicher;

  FakeLoesen(this.speicher);

  @override
  Future<Either<Failure, Mandant>> call(LoeseOrdnerParams params) async {
    final alt = speicher.mandanten.firstWhere((m) => m.id == params.mandantId);
    final neu = mandant(
      alt.id,
      alt.nachname,
      ordner: OrdnernamenMenge([params.ordnername]).ohne(alt.aktenOrdnernamen),
    );
    speicher.ersetze(neu);
    return Right(neu);
  }
}
