namespace AutomationService.Features.RegisterHistorie.Domain.Services;

/// <summary>
/// Die Vollständigkeitsprobe eines Jahrgangs (§6.2): Lücken in der
/// Nummernfolge und Nummern, die die Datei zweimal bringt.
///
/// Die laufende Nummer läuft je Jahr lückenlos von 01 aufwärts. Fehlt Nr. 47,
/// ist eine Zeile verloren gegangen — das ist die eine Fehlerklasse, die kein
/// Erzeuger an sich selbst bemerkt: Bricht er nach Nr. 46 ab, sieht seine Datei
/// vollständig aus. Deshalb rechnet die App sie und nicht er.
/// </summary>
public static class JahrgangPruefung
{
    /// <summary>
    /// Die fehlenden Nummern zwischen 1 und der höchsten Nummer des Jahrgangs.
    ///
    /// Gemessen wird gegen Datei <b>und</b> Bestand zusammen: Wer einen
    /// Jahrgang in zwei Läufen einliest, bekäme sonst beim zweiten Lauf alle
    /// Nummern des ersten als Lücke gemeldet. Die höchste Nummer ist die Grenze
    /// und nicht etwa eine Sollzahl — wie viele Akten ein Jahr hatte, weiß nur
    /// das Register selbst.
    /// </summary>
    public static IReadOnlyList<int> Luecken(IEnumerable<int> ausDerDatei, IEnumerable<int> imBestand)
    {
        ArgumentNullException.ThrowIfNull(ausDerDatei);
        ArgumentNullException.ThrowIfNull(imBestand);

        var vorhanden = new HashSet<int>(ausDerDatei.Where(nummer => nummer > 0));
        vorhanden.UnionWith(imBestand.Where(nummer => nummer > 0));
        if (vorhanden.Count == 0) return [];

        var hoechste = vorhanden.Max();
        return [.. Enumerable.Range(1, hoechste).Where(nummer => !vorhanden.Contains(nummer))];
    }

    /// <summary>
    /// Die Nummern, die in <em>dieser Datei</em> mehr als einmal vorkommen — in
    /// der Reihenfolge ihres ersten Auftretens, damit der Bericht der Datei
    /// folgt.
    ///
    /// Verglichen wird das Paar aus Nummer und Zusatz: <c>10/19</c> und
    /// <c>10/19-I</c> sind zwei Akten und keine Dublette. Eine Nummer, die es
    /// schon im Bestand gibt, ist ebenfalls keine — sie zählt als
    /// „unveraendert".
    /// </summary>
    public static IReadOnlyList<int> Doppelte(IEnumerable<(int Nummer, string Zusatz)> ausDerDatei)
    {
        ArgumentNullException.ThrowIfNull(ausDerDatei);

        var gesehen = new HashSet<(int, string)>();
        var doppelt = new List<int>();
        foreach (var (nummer, zusatz) in ausDerDatei)
        {
            var schluessel = Schluessel(nummer, zusatz);
            if (!gesehen.Add(schluessel) && !doppelt.Contains(nummer)) doppelt.Add(nummer);
        }

        return doppelt;
    }

    /// <summary>
    /// Der natürliche Schlüssel einer Zeile innerhalb ihres Jahrgangs. Der
    /// Zusatz wird getrimmt, weil er aus einer Freitextzelle stammt und ein
    /// angehängtes Leerzeichen sonst zwei Akten aus einer machte.
    /// </summary>
    public static (int Nummer, string Zusatz) Schluessel(int nummer, string? zusatz) =>
        (nummer, (zusatz ?? string.Empty).Trim());
}
