namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Was von den eigenen automatischen Sicherungen im Ablageordner liegt
/// (§7.2, #112): wie viele, und wie weit die Historie zurückreicht.
///
/// <para>
/// Der Reiter „Datensicherung" zeigt beides („27 Sicherungen dieses Rechners,
/// älteste vom 12.03.2026"). Ohne diese Auskunft ist die gestaffelte
/// Aufbewahrung für den Anwalt nicht überprüfbar — er sähe „zuletzt gesichert
/// am …" und wüsste immer noch nicht, ob er auf vorgestern zurückkann.
/// </para>
///
/// <para>
/// <b>Gezählt wird über den Dateinamen</b> (<see cref="SicherungsDateiname"/>),
/// nicht über das Änderungsdatum: Denselben Zeitpunkt, nach dem aufgeräumt wird,
/// soll auch die Anzeige nennen. Umbenannte Dateien und die Archive des anderen
/// Arbeitsplatzes zählen deshalb nicht mit — sie werden auch nicht gelöscht.
/// </para>
/// </summary>
/// <param name="Anzahl">Archive dieses Rechners im Ablageordner.</param>
/// <param name="Aeltestes">Zeitpunkt des ältesten, oder <c>null</c> bei keinem.</param>
/// <param name="Neuestes">Zeitpunkt des jüngsten, oder <c>null</c> bei keinem.</param>
public sealed record SicherungsBestand(int Anzahl, DateTime? Aeltestes, DateTime? Neuestes)
{
    /// <summary>Kein Ordner, kein Zugriff, keine Archive — die Auskunft bleibt eine.</summary>
    public static readonly SicherungsBestand Leer = new(0, null, null);

    /// <summary>
    /// Liest den Bestand. Wirft nie: Die Auskunft hängt an einem Ordner, den der
    /// Anwalt gewählt hat und der offline oder umbenannt sein kann — dann ist der
    /// Bestand leer, und der Rest der Antwort steht trotzdem auf dem Bildschirm.
    /// </summary>
    public static SicherungsBestand Lies(string ordner, string rechnername)
    {
        var archive = Archive(ordner, rechnername);
        return archive.Count == 0
            ? Leer
            : new SicherungsBestand(
                archive.Count,
                archive.Min(eintrag => eintrag.Zeitpunkt),
                archive.Max(eintrag => eintrag.Zeitpunkt));
    }

    /// <summary>
    /// Die eigenen Archive mit Pfad und Zeitpunkt — die Vorlage für die
    /// <see cref="Aufbewahrungsregel"/> und für <see cref="Lies"/>.
    /// </summary>
    public static IReadOnlyList<(string Pfad, DateTime Zeitpunkt)> Archive(
        string ordner, string rechnername)
    {
        if (string.IsNullOrWhiteSpace(ordner))
        {
            return [];
        }

        var gefunden = new List<(string Pfad, DateTime Zeitpunkt)>();
        try
        {
            foreach (var pfad in Directory.EnumerateFiles(
                         ordner,
                         SicherungsDateiname.Suchmuster(rechnername),
                         SearchOption.TopDirectoryOnly))
            {
                var zeitpunkt = SicherungsDateiname.Zeitpunkt(Path.GetFileName(pfad), rechnername);
                if (zeitpunkt is not null)
                {
                    gefunden.Add((pfad, zeitpunkt.Value));
                }
            }
        }
        catch (Exception ex) when (
            ex is IOException or UnauthorizedAccessException or ArgumentException)
        {
            // Ordner weg, Rechte weg, Pfad unbrauchbar: keine Auskunft statt
            // eines Abbruchs — derselbe Grund wie bei der ArbeitsplatzAkte.
            return [];
        }

        return gefunden;
    }
}
