namespace AutomationService.Features.Vollmacht.Domain.Services;

/// <summary>
/// Die Schreiblinie der Vollmacht (§4.11, #171): Ein leeres Feld druckt nicht
/// als Lücke, sondern als Linie aus <see cref="Zeichen"/>, auf der der Mandant
/// von Hand ergänzt. Pflichtfelder gibt es bewusst nicht — die Vollmacht ist
/// ein Papierformular, das er ohnehin unterschreibt.
///
/// Ohne Linie druckte ein fehlender Wert nichts, und die Kommas der Vorlage
/// blieben allein stehen: „Hiermit erteile ich, , , ".
///
/// Die Längen sind Zeichen, keine Maße; sie richten sich danach, was in das
/// Feld üblicherweise hineingeschrieben wird. Wer sie ändert, ändert auch das
/// Gegenstück: Das Frontend nutzt dieselben Längen in <c>VollmachtVorbelegung</c>
/// für das, was es selbst in „wegen" und „in Sachen" schreibt — ein fehlendes
/// Datum als Linie von <see cref="Datum"/>, ein fehlender Name als Linie von
/// <see cref="Name"/> (etwa bei „Strafverfahren gegen" oder „Bußgeldsache").
///
/// Nur für die Vollmacht. Der gemeinsame Ausfüller (<c>WordAutomationService</c>)
/// setzt einen leeren Wert weiter als nichts ein — die Anspruchsschreiben
/// bleiben, wie sie sind.
/// </summary>
public static class VollmachtSchreiblinie
{
    /// <summary>Das Zeichen der Linie; in Word eine durchgezogene Unterstreichung.</summary>
    public const char Zeichen = '_';

    public const int Vorname = 14;
    public const int Nachname = 18;

    /// <summary>
    /// Ein ganz leerer Name — weder Vor- noch Nachname — ist eine einzige
    /// Linie statt zweier kurzer: Der Mandant schreibt seinen Namen in einem
    /// Zug.
    /// </summary>
    public const int Name = 32;

    public const int Strasse = 26;
    public const int Plz = 9;
    public const int Ort = 18;
    public const int Telefon = 24;

    /// <summary>
    /// Nicht länger: Im Fußblock der Unfallvollmacht (7,5 pt) steht die Linie
    /// hinter „E-Mail Mandant:" neben dem Telefon, und mit 34 Zeichen rutschte
    /// sie in die nächste Zeile (geprüft an der Vorschau der Kanzleivorlage).
    /// </summary>
    public const int Email = 28;

    /// <summary>
    /// Ein Datum: hier für <c>{{Unfalldatum}}</c>, das keine mitgelieferte
    /// Vorlage verwendet, eine der Kanzlei aber verwenden darf; im Frontend für
    /// das fehlende Datum in „wegen".
    /// </summary>
    public const int Datum = 12;

    /// <summary>Eine Linie von <paramref name="laenge"/> Zeichen.</summary>
    public static string Linie(int laenge) => new(Zeichen, laenge);

    /// <summary>
    /// Der Wert ohne Leerraum am Rand — oder die Linie, wenn danach nichts
    /// bleibt. Ein Wert aus Leerzeichen ist also leer.
    /// </summary>
    public static string WertOderLinie(string? wert, int laenge)
    {
        var bereinigt = wert?.Trim() ?? string.Empty;
        return bereinigt.Length > 0 ? bereinigt : Linie(laenge);
    }
}
