import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:equatable/equatable.dart';

/// Stand einer der drei Vollmachtsvorlagen (`VollmachtVorlageDto`).
class VollmachtVorlage extends Equatable {
  /// Null, wenn der Dienst eine Art meldet, die dieses Frontend nicht kennt.
  final VollmachtArt? art;
  final String dateiname;
  final bool vorhanden;
  final DateTime? geaendertAm;

  const VollmachtVorlage({
    required this.art,
    required this.dateiname,
    required this.vorhanden,
    this.geaendertAm,
  });

  factory VollmachtVorlage.fromJson(Map<String, dynamic> json) =>
      VollmachtVorlage(
        art: VollmachtArt.ausWert(json['art'] as String?),
        dateiname: json['dateiname'] as String? ?? '',
        vorhanden: json['vorhanden'] as bool? ?? false,
        geaendertAm: DateTime.tryParse(json['geaendertAm'] as String? ?? ''),
      );

  @override
  List<Object?> get props => [art, dateiname, vorhanden, geaendertAm];
}

/// Antwort auf `GET /api/Vollmacht/vorlagen`: der Unterordner `Vollmacht` des
/// Vorlagenordners und was darin liegt (§4.11). Feste Dateinamen — getauscht
/// wird eine Vorlage im Explorer, nicht in der App.
class VollmachtVorlagenStand extends Equatable {
  final String ordner;
  final List<VollmachtVorlage> vorlagen;

  const VollmachtVorlagenStand({required this.ordner, required this.vorlagen});

  factory VollmachtVorlagenStand.fromJson(Map<String, dynamic> json) =>
      VollmachtVorlagenStand(
        ordner: json['ordner'] as String? ?? '',
        vorlagen: [
          for (final eintrag in json['vorlagen'] as List? ?? const [])
            if (eintrag is Map<String, dynamic>)
              VollmachtVorlage.fromJson(eintrag),
        ],
      );

  /// Die Vorlage zu [art]; null, wenn der Dienst sie nicht gemeldet hat.
  VollmachtVorlage? zu(VollmachtArt art) {
    for (final vorlage in vorlagen) {
      if (vorlage.art == art) return vorlage;
    }
    return null;
  }

  /// Ob die Vorlage zu [art] im Ordner liegt.
  bool hat(VollmachtArt art) => zu(art)?.vorhanden ?? false;

  @override
  List<Object?> get props => [ordner, vorlagen];
}
