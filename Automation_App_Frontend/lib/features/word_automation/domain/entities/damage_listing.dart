import 'package:equatable/equatable.dart';

/// Schadensaufstellung für Vorlagen "mit Auflistung". Wird im Backend als Tabelle
/// am Platzhalter {{Schadensaufstellung}} eingefügt; die RVG-Kosten werden daraus berechnet.
class DamageListing extends Equatable {
  final List<DamageItem> items;

  /// Gebührensatz der Geschäftsgebühr, üblicherweise 1,3.
  final double gebuehrensatz;

  /// True, wenn der Mandant nicht vorsteuerabzugsberechtigt ist (Umsatzsteuer ausweisen).
  final bool applyVat;

  /// Manuell korrigierte Geschäftsgebühr in €; null = automatisch nach § 13 RVG.
  final double? geschaeftsgebuehrOverride;

  /// Manuell korrigierte Auslagenpauschale in €; null = Nr. 7002 VV RVG (20 %, max. 20 €).
  final double? auslagenpauschaleOverride;

  /// Farbe der Titelzeile der Tabelle als Hex-Wert "RRGGBB" (aus den Einstellungen);
  /// null = Standardgrau des Backends.
  final String? headerColorHex;

  const DamageListing({
    required this.items,
    this.gebuehrensatz = 1.3,
    this.applyVat = false,
    this.geschaeftsgebuehrOverride,
    this.auslagenpauschaleOverride,
    this.headerColorHex,
  });

  /// JSON-Form — identisch zum Request an das Backend und zur Persistenz am
  /// Vorgang (Wiederverwendung beim nächsten Schreiben desselben Vorgangs).
  Map<String, dynamic> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'gebuehrensatz': gebuehrensatz,
    'applyVat': applyVat,
    'geschaeftsgebuehrOverride': geschaeftsgebuehrOverride,
    'auslagenpauschaleOverride': auslagenpauschaleOverride,
    'headerColorHex': headerColorHex,
  };

  factory DamageListing.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    return DamageListing(
      items: items is List
          ? [
              for (final item in items)
                if (item is Map<String, dynamic>) DamageItem.fromJson(item),
            ]
          : const [],
      gebuehrensatz: (json['gebuehrensatz'] as num?)?.toDouble() ?? 1.3,
      applyVat: json['applyVat'] as bool? ?? false,
      geschaeftsgebuehrOverride: (json['geschaeftsgebuehrOverride'] as num?)
          ?.toDouble(),
      auslagenpauschaleOverride: (json['auslagenpauschaleOverride'] as num?)
          ?.toDouble(),
      headerColorHex: json['headerColorHex'] as String?,
    );
  }

  /// Kopie mit der Titelzeilen-Farbe aus den Einstellungen (wird beim Erfassen
  /// im Wizard ergänzt, das Formular selbst kennt die Einstellungen nicht).
  DamageListing withHeaderColor(String? hex) => DamageListing(
    items: items,
    gebuehrensatz: gebuehrensatz,
    applyVat: applyVat,
    geschaeftsgebuehrOverride: geschaeftsgebuehrOverride,
    auslagenpauschaleOverride: auslagenpauschaleOverride,
    headerColorHex: hex,
  );

  @override
  List<Object?> get props => [
    items,
    gebuehrensatz,
    applyVat,
    geschaeftsgebuehrOverride,
    auslagenpauschaleOverride,
    headerColorHex,
  ];
}

class DamageItem extends Equatable {
  final String description;
  final double amount;

  const DamageItem({required this.description, required this.amount});

  Map<String, dynamic> toJson() => {
    'description': description,
    'amount': amount,
  };

  factory DamageItem.fromJson(Map<String, dynamic> json) => DamageItem(
    description: json['description'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
  );

  @override
  List<Object> get props => [description, amount];
}
