import 'dart:async';

/// Nach erfolgreichem Import müssen sämtliche Formulare und Router neu entstehen.
abstract final class DatenstandSignal {
  static final StreamController<String> _controller =
      StreamController<String>.broadcast();

  static final StreamController<bool> _arbeit =
      StreamController<bool>.broadcast();
  static Stream<bool> get arbeit => _arbeit.stream;
  static void beschaeftigt(bool wert) => _arbeit.add(wert);

  static Stream<String> get aenderungen => _controller.stream;

  static String? _letzteMeldung;
  static String? nimmMeldung() {
    final meldung = _letzteMeldung;
    _letzteMeldung = null;
    return meldung;
  }

  static void uebernommen(String meldung) {
    _letzteMeldung = meldung;
    _controller.add(meldung);
  }
}
