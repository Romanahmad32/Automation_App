import 'dart:async';

import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_hervorhebung_signal.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgang_verwaltung_tile.dart';
import 'package:flutter/material.dart';

/// Die Liste der Vorgangskacheln in „Vorgänge verwalten" — und die Stelle, die
/// den Sprung aus dem Register beantwortet (§6.2).
///
/// Eigener Baustein statt einer `ListView` in der Seite, weil hier Zustand
/// hängt: Scrollstellung, die hervorgehobene Zeile und der Wecker, der die
/// Hervorhebung wieder ausgehen lässt.
class VorgaengeListe extends StatefulWidget {
  /// Die Vorgänge in Anzeigereihenfolge.
  final List<Vorgang> vorgaenge;

  final ValueChanged<Vorgang> onEdit;
  final ValueChanged<Vorgang> onDelete;

  /// Wie lange eine angesprungene Zeile hervorgehoben bleibt. Lang genug, um
  /// sie nach dem Tabwechsel mit den Augen zu finden, kurz genug, dass die
  /// Liste danach wieder eine gewöhnliche Liste ist.
  static const Duration hervorhebungsdauer = Duration(seconds: 4);

  const VorgaengeListe({
    super.key,
    required this.vorgaenge,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<VorgaengeListe> createState() => VorgaengeListeState();
}

class VorgaengeListeState extends State<VorgaengeListe> {
  final ScrollController _scroll = ScrollController();
  final VorgangHervorhebungSignal _signal = getIt<VorgangHervorhebungSignal>();

  String? _hervorgehoben;
  Timer? _wecker;

  @override
  void initState() {
    super.initState();
    _signal.pendingReferenz.addListener(_signalVerarbeiten);
    // Das Signal kann schon stehen, bevor diese Liste zum ersten Mal gebaut
    // wird — beim allerersten Wechsel in den Tab gibt es noch keinen Lauscher.
    _signalVerarbeiten();
  }

  @override
  void dispose() {
    _signal.pendingReferenz.removeListener(_signalVerarbeiten);
    _wecker?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: _scroll,
    padding: const EdgeInsets.only(bottom: 24),
    itemCount: widget.vorgaenge.length,
    itemBuilder: (context, index) {
      final vorgang = widget.vorgaenge[index];
      return VorgangVerwaltungTile(
        key: ValueKey(vorgang.referenz),
        vorgang: vorgang,
        hervorgehoben: vorgang.referenz == _hervorgehoben,
        onEdit: () => widget.onEdit(vorgang),
        onDelete: () => widget.onDelete(vorgang),
      );
    },
  );

  void _signalVerarbeiten() {
    final referenz = _signal.pendingReferenz.value;
    if (referenz == null) return;
    _signal.loesche();

    setState(() => _hervorgehoben = referenz);
    _wecker?.cancel();
    _wecker = Timer(VorgaengeListe.hervorhebungsdauer, () {
      if (mounted) setState(() => _hervorgehoben = null);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _hinScrollen(referenz));
  }

  /// Scrollt die angesprungene Zeile in Sicht.
  ///
  /// In zwei Schritten, weil `ListView.builder` nur baut, was sichtbar ist:
  /// Eine Zeile weit außerhalb hat gar keinen `BuildContext`, an dem
  /// `ensureVisible` ansetzen könnte. Der erste Schritt springt deshalb
  /// anteilig — die Kacheln sind fast gleich hoch, das landet im Bereich der
  /// gesuchten —, der zweite rückt im nächsten Bild genau zurecht.
  void _hinScrollen(String referenz) {
    final index = widget.vorgaenge.indexWhere((v) => v.referenz == referenz);
    if (index < 0 || !_scroll.hasClients) return;

    final anteil = index / widget.vorgaenge.length;
    final ziel = anteil * _scroll.position.maxScrollExtent;
    _scroll.jumpTo(ziel.clamp(0.0, _scroll.position.maxScrollExtent));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final kachel = _kachelKontext(referenz);
      if (kachel == null) return;
      Scrollable.ensureVisible(
        kachel,
        alignment: 0.3,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// Der Kontext der Kachel zu [referenz], sofern sie gerade gebaut ist.
  BuildContext? _kachelKontext(String referenz) {
    BuildContext? treffer;
    void suche(Element element) {
      if (treffer != null) return;
      final widget = element.widget;
      if (widget is VorgangVerwaltungTile &&
          widget.vorgang.referenz == referenz) {
        treffer = element;
        return;
      }
      element.visitChildren(suche);
    }

    if (!mounted) return null;
    context.visitChildElements(suche);
    return treffer;
  }
}
