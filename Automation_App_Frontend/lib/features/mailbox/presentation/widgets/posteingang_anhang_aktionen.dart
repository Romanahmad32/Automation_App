import 'package:automation_app/features/mailbox/domain/entities/posteingang_anhang.dart';

/// Die Brücke zwischen dem Anhang-Detail und den Handgriffen (§4.3): drei
/// Handlungen zu einem Anhang, alle asynchron, weil jede ihn zuerst ins
/// Zwischenlager holt (`PosteingangCubit.anhangLaden`), bevor sie etwas damit
/// tut.
///
/// Reiner Datenhalter ohne eigenes Verhalten. Welche Handlung sich hinter
/// jedem Feld verbirgt — öffnen (`PosteingangDateiOeffnen`), in die Akte
/// legen (`PosteingangAktenAblageDialog`), beim Versand mitgeben
/// (`EmailVersandDialog`) —, entscheidet die Stelle, die diese Klasse
/// zusammenbaut (`posteingang_detail.dart`); die Anhangliste kennt weder
/// `PosteingangCubit` noch `AblageCubit` noch `EmailEntwurfCubit`.
class PosteingangAnhangAktionen {
  const PosteingangAnhangAktionen({
    required this.onOeffnen,
    required this.onInDieAkte,
    required this.onBeimVersand,
    this.laeuft = false,
  });

  /// Lädt den Anhang bei Bedarf und öffnet ihn im dafür eingerichteten
  /// Programm.
  final Future<void> Function(PosteingangAnhang anhang) onOeffnen;

  /// Lädt den Anhang und legt ihn über die vorhandene Ablage in der Akte ab.
  final Future<void> Function(PosteingangAnhang anhang) onInDieAkte;

  /// Lädt den Anhang und bietet ihn im Versanddialog als Anhang an.
  final Future<void> Function(PosteingangAnhang anhang) onBeimVersand;

  /// True, während ein Anhang gerade ins Zwischenlager geholt wird — der Ring
  /// an der Zeile; die übrigen Listenknöpfe bleiben währenddessen bedienbar
  /// (eine laufende Downloadverbindung blockiert das Blättern nicht extra).
  final bool laeuft;
}
