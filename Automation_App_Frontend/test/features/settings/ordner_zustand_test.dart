import 'package:automation_app/features/settings/domain/entities/ordner_zustand.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hält die fünf Schlüssel fest, mit denen `GET /api/Settings/ordner`
/// beantwortet wird.
///
/// Frontend und Backend sind hier über nichts als Zeichenketten verbunden.
/// Ein Tippfehler in einem dieser Namen ist kein Compilerfehler und keine rote
/// Prüfkette, sondern zur Laufzeit ein leeres Feld — und weil die Zustandszeile
/// bei leerem Feld schlicht nichts sagt, fiele ausgerechnet der Fall nicht auf,
/// für den es sie gibt: ein Ordner, der auf diesem Rechner nicht auflösbar ist.
void main() {
  test('liest alle fünf Felder des Vertrags', () {
    final zustand = OrdnerZustand.fromJson(const {
      'feld': 'appDatenOrdner',
      'gespeichert': r'%OneDriveCommercial%\Kanzlei App Daten',
      'wirksam': r'C:\Users\anwalt\OneDrive - Kanzlei\Kanzlei App Daten',
      'zustand': 'bereit',
      'anker': 'OneDriveCommercial',
    });

    expect(zustand.feld, 'appDatenOrdner');
    expect(zustand.gespeichert, r'%OneDriveCommercial%\Kanzlei App Daten');
    expect(
      zustand.wirksam,
      r'C:\Users\anwalt\OneDrive - Kanzlei\Kanzlei App Daten',
    );
    expect(zustand.zustand, OrdnerZustandArten.bereit);
    expect(zustand.anker, 'OneDriveCommercial');
  });

  /// Ein abgeleiteter Ordner hat keine eigene Speicherform und keinen Anker —
  /// der Dienst schickt dafür leere Zeichenketten, keine `null`. Beides muss
  /// hier ankommen, ohne dass etwas wirft.
  test('kommt mit leeren Zeichenketten zurecht', () {
    final zustand = OrdnerZustand.fromJson(const {
      'feld': 'registerAblageOrdner',
      'gespeichert': '',
      'wirksam': r'C:\OneDrive\Kanzlei App Daten\Register',
      'zustand': 'abgeleitet',
      'anker': '',
    });

    expect(zustand.gespeichert, isEmpty);
    expect(zustand.anker, isEmpty);
    expect(zustand.zustand, OrdnerZustandArten.abgeleitet);
    expect(zustand.stoert, isFalse);
  });

  /// Fehlende Schlüssel dürfen die Anzeige nicht sprengen: Ein älterer Dienst
  /// neben einer neueren App ist beim Entwickeln der Normalfall.
  test('fällt bei fehlenden Schlüsseln auf leere Werte zurück', () {
    final zustand = OrdnerZustand.fromJson(const {'feld': 'vorlagenOrdner'});

    expect(zustand.zustand, OrdnerZustandArten.nichtGesetzt);
    expect(zustand.gespeichert, isEmpty);
    expect(zustand.wirksam, isEmpty);
    expect(zustand.anker, isEmpty);
  });

  /// Der eine Zustand, der als Fehler gezeigt gehört — und der einzige, den
  /// niemand still „repariert", indem er auf eine andere OneDrive-Wurzel
  /// ausweicht.
  test('erkennt den fehlenden Anker als störend', () {
    final zustand = OrdnerZustand.fromJson(const {
      'feld': 'appDatenOrdner',
      'gespeichert': r'%OneDriveCommercial%\Kanzlei App Daten',
      'wirksam': '',
      'zustand': 'ankerFehlt',
      'anker': 'OneDriveCommercial',
    });

    expect(zustand.stoert, isTrue);
    expect(
      OrdnerZustand.fromJson(const {
        'feld': 'appDatenOrdner',
        'zustand': 'ordnerFehlt',
      }).stoert,
      isFalse,
      reason:
          'Ein Ordner, der beim ersten Schreiben entsteht, ist kein Fehler — '
          'sonst stünde direkt nach der Wahl ein rotes Symbol da.',
    );
  });
}
