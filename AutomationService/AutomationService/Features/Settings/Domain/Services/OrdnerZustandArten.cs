namespace AutomationService.Features.Settings.Domain.Services;

/// <summary>
/// Die moeglichen Lagen eines Ordnerfelds (#103) — als Konstanten, weil sie
/// ueber die Leitung gehen und die Oberflaeche daraus einen Satz in Klartext
/// baut. Ein Tippfehler waere sonst zur Laufzeit eine Zustandszeile, die
/// niemand sieht.
/// </summary>
public static class OrdnerZustandArten
{
    /// <summary>Nichts eingestellt, und es gibt auch nichts abzuleiten.</summary>
    public const string NichtGesetzt = "nichtGesetzt";

    /// <summary>Feld leer, der wirksame Ordner kommt aus dem App-Daten-Ordner.</summary>
    public const string Abgeleitet = "abgeleitet";

    /// <summary>
    /// Nur beim Vorlagenordner: Feld leer, kein App-Daten-Ordner — es gilt der
    /// App-Ordner unter %APPDATA%, der Stand vor allen Ordnereinstellungen.
    /// </summary>
    public const string Standard = "standard";

    /// <summary>Gesetzt, aufgeloest, der Ordner ist da.</summary>
    public const string Bereit = "bereit";

    /// <summary>
    /// Gesetzt und aufgeloest, aber der Ordner existiert (noch) nicht. Kein
    /// Fehler: Angelegt wird beim ersten Schreiben, nicht beim Speichern.
    /// </summary>
    public const string OrdnerFehlt = "ordnerFehlt";

    /// <summary>
    /// Relativ gespeichert, aber die Umgebungsvariable des Ankers ist auf
    /// diesem Rechner nicht gesetzt — etwa ein gegen das Geschaeftskonto
    /// gespeicherter Pfad auf einem Rechner, der nur ein privates OneDrive
    /// kennt. Der Dienst weicht dann ausdruecklich <em>nicht</em> auf den
    /// anderen Baum aus; die Einstellung sagt, was fehlt.
    /// </summary>
    public const string AnkerFehlt = "ankerFehlt";
}
