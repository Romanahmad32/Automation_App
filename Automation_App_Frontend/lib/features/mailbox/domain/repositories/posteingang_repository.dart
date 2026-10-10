import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/domain/entities/posteingang_anhang.dart';

abstract class PosteingangRepository {
  Future<PosteingangSeite> ladeSeite({String? cursor});
  Future<PosteingangInhalt> ladeInhalt(String id);

  /// Holt **einen** Anhang ins Zwischenlager des Dienstes und gibt seinen
  /// Pfad zurück — nie Bytes: Öffnen, Ablegen in der Akte und Anhängen an eine
  /// ausgehende Mail arbeiten in dieser App überall mit lokalen Pfaden.
  ///
  /// [anhangId] ist die Kennung aus [PosteingangAnhang.id]. Liegt die Datei
  /// schon im Zwischenlager, kommt der Pfad ohne neuen Abruf zurück.
  Future<PosteingangAnhangAblage> ladeAnhang(String id, String anhangId);

  /// Legt die ganze Nachricht als `.eml` im Zwischenlager ab — der Weg, eine
  /// Mail unverändert zu sichern oder in die Akte zu geben.
  Future<PosteingangAnhangAblage> ladeEml(String id);

  /// Bricht laufende Listen- und Inhaltsabrufe ab. **Nicht** die Downloads:
  /// ein angefangener Anhang soll weiterlaufen, während der Anwalt blättert.
  void abbrechen();
}

class PosteingangFehler implements Exception {
  final String meldung;
  const PosteingangFehler(this.meldung);
}
