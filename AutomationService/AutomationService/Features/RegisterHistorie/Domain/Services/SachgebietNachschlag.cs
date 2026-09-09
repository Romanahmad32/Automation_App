using AutomationService.Features.Sachgebiete.Domain.Persistence;
using AutomationService.Features.Sachgebiete.Domain.Services;

namespace AutomationService.Features.RegisterHistorie.Domain.Services;

/// <summary>
/// Der Sachgebietskatalog (§7.1), einmal für einen Importlauf aufbereitet:
/// Kürzel → Eintrag, und die Menge aller Rechtsgebietsnamen.
///
/// Einmal und nicht je Zeile, weil ein Jahrgang rund 200 Zeilen hat und jede
/// davon zweimal im Katalog nachschlägt — mit einer Liste wären das 4800
/// Durchläufe für zwölf Einträge.
///
/// Verglichen wird ohne Rücksicht auf Groß-/Kleinschreibung und mit
/// abgeschnittenen Leerzeichen: Der gewachsene Bestand schreibt „C 03o" und
/// „c03o" für dasselbe Sachgebiet, und ein Katalogabgleich, der daran
/// scheitert, meldet lauter Widersprüche, die keine sind.
/// </summary>
public sealed class SachgebietNachschlag
{
    readonly Dictionary<string, SachgebietEntity> _nachKuerzel =
        new(StringComparer.OrdinalIgnoreCase);

    readonly HashSet<string> _rechtsgebiete = new(StringComparer.OrdinalIgnoreCase);

    public SachgebietNachschlag(IEnumerable<SachgebietEntity> katalog)
    {
        ArgumentNullException.ThrowIfNull(katalog);
        foreach (var eintrag in katalog)
        {
            _nachKuerzel[AbteilungKuerzel.Normalisiere(eintrag.Kuerzel)] = eintrag;
            Merke(eintrag.RechtsgebietVorschlag);
            Merke(eintrag.Name);
        }
    }

    /// <summary>Der Katalogeintrag zu einem Kürzel, oder <c>null</c>.</summary>
    public SachgebietEntity? Eintrag(string? kuerzel)
    {
        var bereinigt = AbteilungKuerzel.Normalisiere(kuerzel);
        return bereinigt.Length == 0 ? null : _nachKuerzel.GetValueOrDefault(bereinigt);
    }

    /// <summary>
    /// Ob dieser Rechtsgebietsname überhaupt im Katalog vorkommt — als
    /// Vorschlag oder als Sachgebietsname. „Vertragsrecht" tut es nicht: Es
    /// hatte nie ein eigenes Kürzel und steht deshalb bewusst nicht im Seed.
    /// </summary>
    public bool KenntRechtsgebiet(string? rechtsgebiet) =>
        _rechtsgebiete.Contains((rechtsgebiet ?? string.Empty).Trim());

    /// <summary>
    /// Ob dieses Kürzel das Rechtsgebiet trägt — es selbst <b>oder</b> sein
    /// Stammkürzel.
    ///
    /// Der Stamm ist die Zahl ohne den Buchstaben dahinter (<c>C03o</c> →
    /// <c>C03</c>, <c>C06s</c> → <c>C06</c>), und genau so ist der Katalog
    /// gebaut: „03 Verkehrsrecht" und darunter „03o
    /// Ordnungswidrigkeitssache". Der Buchstabe benennt die <em>Art</em> der
    /// Sache, nicht ein anderes Rechtsgebiet — eine Bußgeldsache aus dem
    /// Straßenverkehr steht im Register seit jeher unter „Verkehrsrecht".
    ///
    /// Ohne diese Regel meldete die Übernahme jede Bußgeldsache des Bestands
    /// als Widerspruch. Das wäre nicht strenger, sondern nutzlos: Ein Bericht,
    /// in dem alles auffällt, zeigt nichts.
    /// </summary>
    public bool Deckt(string? kuerzel, string rechtsgebiet)
    {
        var eintrag = Eintrag(kuerzel);
        if (eintrag is not null && Passt(eintrag, rechtsgebiet)) return true;

        var stamm = Stamm(AbteilungKuerzel.Normalisiere(kuerzel));
        var stammEintrag = stamm.Length == 0 ? null : Eintrag(stamm);
        return stammEintrag is not null && Passt(stammEintrag, rechtsgebiet);
    }

    /// <summary>
    /// Ob der Katalogeintrag dieses Rechtsgebiet trägt. Geprüft wird gegen
    /// beide Namen: Die Registerspalte schreibt „Zivilrecht", der Katalog führt
    /// „Zivilrecht (allgemein)" mit dem Vorschlag „Zivilrecht".
    /// </summary>
    public static bool Passt(SachgebietEntity eintrag, string rechtsgebiet)
    {
        ArgumentNullException.ThrowIfNull(eintrag);
        var gesucht = (rechtsgebiet ?? string.Empty).Trim();
        return string.Equals(eintrag.RechtsgebietVorschlag.Trim(), gesucht, StringComparison.OrdinalIgnoreCase)
            || string.Equals(eintrag.Name.Trim(), gesucht, StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>
    /// Das Kürzel bis einschließlich seiner Ziffern (<c>C01a</c> → <c>C01</c>).
    /// Leer, wenn gar keine Ziffer darin steht — dann gibt es keinen Stamm,
    /// gegen den sich prüfen ließe.
    /// </summary>
    static string Stamm(string kuerzel)
    {
        var ende = 0;
        while (ende < kuerzel.Length && !char.IsAsciiDigit(kuerzel[ende])) ende++;
        while (ende < kuerzel.Length && char.IsAsciiDigit(kuerzel[ende])) ende++;
        return ende == kuerzel.Length ? string.Empty : kuerzel[..ende];
    }

    void Merke(string? name)
    {
        var bereinigt = (name ?? string.Empty).Trim();
        if (bereinigt.Length > 0) _rechtsgebiete.Add(bereinigt);
    }
}
