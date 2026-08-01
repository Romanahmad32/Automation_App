/// Zerlegt eine Referenz „Nr/Jahr Abteilung_Kennzeichen" in ihre Bestandteile.
class ReferenzTeile {
  final int? nummer;
  final String jahr;
  final String abteilung;
  final String kennzeichen;

  const ReferenzTeile({
    required this.nummer,
    required this.jahr,
    required this.abteilung,
    required this.kennzeichen,
  });

  static final RegExp _muster = RegExp(r'^\s*(\d+)\s*/\s*(\d+)\s+(\S+)_(.+)$');

  static ReferenzTeile? parse(String referenz) {
    final match = _muster.firstMatch(referenz);
    if (match == null) return null;
    return ReferenzTeile(
      nummer: int.tryParse(match.group(1)!),
      jahr: match.group(2)!,
      abteilung: match.group(3)!,
      kennzeichen: match.group(4)!.trim(),
    );
  }
}
