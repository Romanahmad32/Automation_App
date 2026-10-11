import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_auftrag.dart';
import 'package:equatable/equatable.dart';

/// Die ausgefüllte Vollmacht, die der Dialog in Word geöffnet hat — gewollt
/// („In Word öffnen") oder als Rückfall nach einem gescheiterten Druck
/// (§4.11, #174). Der Dialog bleibt dabei in der Eingabe; die Leiste über den
/// Knöpfen nennt diese Fassung.
///
/// [auftrag] ist der Stand, aus dem sie entstand: Ist er beim nächsten
/// „In Word öffnen" derselbe, öffnet der Dialog dieselbe Datei noch einmal,
/// statt neu auszufüllen — eine neue Fassung scheiterte ohnehin, solange Word
/// die alte offen hält.
class VollmachtWordFassung extends Equatable {
  final String pfad;
  final VollmachtAuftrag auftrag;

  /// Wann sie zuletzt geöffnet wurde — die Leiste nennt die Uhrzeit.
  final DateTime zeitpunkt;

  /// Ob sich Word anstoßen ließ; sonst sagt die Leiste das und bietet den
  /// Explorer an.
  final bool geoeffnet;

  const VollmachtWordFassung({
    required this.pfad,
    required this.auftrag,
    required this.zeitpunkt,
    required this.geoeffnet,
  });

  /// Der Dateiname ohne Ordner, etwa „Vollmacht Unfallsachen.docx".
  String get dateiname => pfad.split(RegExp(r'[\\/]')).last;

  /// Dieselbe Datei, um [zeitpunkt] noch einmal in Word geöffnet.
  VollmachtWordFassung erneutGeoeffnet(DateTime zeitpunkt) =>
      VollmachtWordFassung(
        pfad: pfad,
        auftrag: auftrag,
        zeitpunkt: zeitpunkt,
        geoeffnet: true,
      );

  @override
  List<Object?> get props => [pfad, auftrag, zeitpunkt, geoeffnet];
}
