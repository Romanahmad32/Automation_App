namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Welche automatischen Sicherungen liegen bleiben (§7.2, #112) — gestaffelt
/// nach Alter statt begrenzt nach Anzahl.
///
/// <para>
/// <b>Warum nicht mehr „die letzten zehn".</b> Das trug, solange einmal je
/// Sitzung gesichert wurde. Mit dem <c>SicherungsZeitgeber</c> (alle 30 Minuten)
/// decken zehn Archive keinen Arbeitstag mehr ab — ausgerechnet der Fall, für den
/// man eine Sicherung braucht („vorgestern war der Bestand noch in Ordnung"),
/// wäre dann als Erstes weg. Die Staffel hält die Zahl in derselben
/// Größenordnung (rund 10 + 7 + 8 + 12 je Rechner) und reicht trotzdem Monate
/// zurück.
/// </para>
///
/// <para>
/// <b>Rein, ohne IO.</b> Damit sich die Regel mit Hunderten Zeitpunkten in einem
/// Test durchspielen lässt, statt Dateien anzulegen; gelöscht wird nebenan
/// (<see cref="SicherungsAufraeumung"/>).
/// </para>
///
/// <para>
/// Gerechnet wird in lokaler Kalenderzeit auf dem Zeitpunkt aus dem
/// <see cref="SicherungsDateiname"/> — nicht auf dem Änderungsdatum der Datei,
/// das der Synchronisierungsdienst beim Herunterladen neu setzt.
/// </para>
/// </summary>
public static class Aufbewahrungsregel
{
    /// <summary>So viele Tage zurück bleibt je Kalendertag die jüngste Sicherung.</summary>
    public const int TageEinzeln = 7;

    /// <summary>So viele 7-Tage-Blöcke danach bleibt je Block die jüngste.</summary>
    public const int WochenEinzeln = 8;

    /// <summary>Davor je Kalendermonat die jüngste — aber höchstens so viele Monate.</summary>
    public const int MonateHoechstens = 12;

    const int TageJeWoche = 7;

    /// <summary>Ab diesem Tagesabstand zählt nur noch der Kalendermonat.</summary>
    const int WochenGrenze = TageEinzeln + (WochenEinzeln * TageJeWoche);

    const char MonatsFach = 'M';

    /// <summary>
    /// Die Pfade, die gelöscht werden sollen; alles Übrige bleibt liegen.
    ///
    /// <para>
    /// Das global neueste Archiv ist nie dabei — auch dann nicht, wenn die
    /// Staffel es fällig machte (ein Rechner, der monatelang aus war). Ein Ordner
    /// ohne die jüngste Sicherung wäre kein Ordner mit Historie, sondern einer
    /// ohne Sicherung.
    /// </para>
    /// </summary>
    public static IReadOnlyList<string> ZuLoeschen(
        IEnumerable<(string Pfad, DateTime Zeitpunkt)> archive, DateTime jetzt)
    {
        ArgumentNullException.ThrowIfNull(archive);

        var nachAlter = archive.OrderByDescending(eintrag => eintrag.Zeitpunkt).ToList();
        if (nachAlter.Count == 0)
        {
            return [];
        }

        var behalten = new HashSet<string>(StringComparer.Ordinal) { nachAlter[0].Pfad };
        var belegteFaecher = new HashSet<(char Art, int Erstes, int Zweites)>();
        var monate = 0;

        foreach (var (pfad, zeitpunkt) in nachAlter)
        {
            var fach = Fach((jetzt.Date - zeitpunkt.Date).Days, zeitpunkt);
            if (fach is null)
            {
                // Heute — und alles, was in der Zukunft datiert ist: Eine falsch
                // gestellte Uhr am anderen Arbeitsplatz darf keine Sicherung kosten.
                behalten.Add(pfad);
                continue;
            }

            // Der erste Treffer je Fach ist der jüngste, die Liste läuft absteigend.
            if (!belegteFaecher.Add(fach.Value))
            {
                continue;
            }

            // Die Monatsvertreter sind ebenfalls absteigend, deshalb genügt das
            // Mitzählen: Was über der Grenze liegt, ist der ältere Teil.
            if (fach.Value.Art == MonatsFach && ++monate > MonateHoechstens)
            {
                continue;
            }

            behalten.Add(pfad);
        }

        return nachAlter
            .Where(eintrag => !behalten.Contains(eintrag.Pfad))
            .Select(eintrag => eintrag.Pfad)
            .ToList();
    }

    /// <summary>
    /// Das Fach, um das ein Archiv mit den anderen konkurriert: der Kalendertag,
    /// der 7-Tage-Block oder der Kalendermonat. <c>null</c> heißt „ohne
    /// Konkurrenz" — heute wird alles behalten.
    /// </summary>
    static (char Art, int Erstes, int Zweites)? Fach(int tagesabstand, DateTime zeitpunkt) =>
        tagesabstand switch
        {
            <= 0 => null,
            <= TageEinzeln => ('T', tagesabstand, 0),
            <= WochenGrenze => ('W', (tagesabstand - TageEinzeln - 1) / TageJeWoche, 0),
            _ => (MonatsFach, zeitpunkt.Year, zeitpunkt.Month),
        };
}
