using System.Text.Json;
using AutomationService.Core.Ablage;
using AutomationService.Core.Lifetime;

namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Die Akten der Arbeitsplätze im gemeinsamen Sicherungsordner (§7.2, #39):
/// je Rechner eine Datei <c>arbeitsplatz-&lt;Rechnername&gt;.json</c>.
///
/// <para>
/// <b>Warum je Rechner eine Datei und nicht eine gemeinsame.</b> Das Issue nennt
/// <c>arbeitsplatz.json</c>. Eine einzige Datei, die beide Rechner beschreiben,
/// ist aber genau der Fall, für den ein Synchronisierungsdienst Konfliktkopien
/// anlegt — die Datei, die vor dem Überschreiben warnen soll, wäre die erste,
/// die sich selbst dupliziert. Jeder schreibt nur seine eigene; gelesen werden
/// alle.
/// </para>
///
/// <para>
/// <b>Gelesen wird nachsichtig.</b> Ein halb übertragener oder von Hand
/// verunstalteter Eintrag wird übersprungen, nicht geworfen. Der andere
/// Arbeitsplatz darf am Start dieses Rechners nichts kaputt machen können; im
/// schlimmsten Fall bleibt ein Übergabe-Angebot aus, und der Anwalt spielt die
/// Sicherung von Hand ein.
/// </para>
///
/// <para>
/// <b>Geschrieben wird über <see cref="AtomareAblage"/></b> — aus demselben
/// Grund wie beim Register-Spiegel: Der Synchronisierer reagiert auf
/// Dateiänderungen, nicht auf „fertig geschrieben".
/// </para>
/// </summary>
public static class ArbeitsplatzAkte
{
    public const string DateiPraefix = "arbeitsplatz-";
    public const string DateiEndung = ".json";

    /// <summary>Alles, was hier hineingehört, in einem Suchmuster.</summary>
    public const string Suchmuster = DateiPraefix + "*" + DateiEndung;

    static readonly JsonSerializerOptions Format = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        // Eingerückt, weil die Datei im OneDrive-Ordner des Anwalts liegt und
        // dort auch von einem Menschen aufgeschlagen wird.
        WriteIndented = true,
    };

    /// <summary>Der Name dieses Rechners, tauglich als Bestandteil eines Dateinamens.</summary>
    public static string DieserRechner { get; } = Bereinige(Environment.MachineName);

    public static string DateinameFuer(string rechnername) =>
        $"{DateiPraefix}{Bereinige(rechnername)}{DateiEndung}";

    /// <summary>Die eigene Akte, oder <c>null</c>, wenn dieser Rechner noch keine hat.</summary>
    public static ArbeitsplatzEintrag? LiesEigene(string ordner) =>
        LiesDatei(Path.Combine(ordner, DateinameFuer(DieserRechner)));

    /// <summary>
    /// Die Akten der <em>anderen</em> Arbeitsplätze, je Rechner die neueste.
    ///
    /// Die Entdopplung ist kein Übereifer: Eine Konfliktkopie
    /// („arbeitsplatz-BUERO-PC (2).json") trägt denselben Rechnernamen im Inhalt
    /// und würde sonst als zweiter Arbeitsplatz gelten — mit einem älteren Stand,
    /// der ein Angebot verdrängen könnte.
    /// </summary>
    public static IReadOnlyList<ArbeitsplatzEintrag> LiesFremde(string ordner)
    {
        if (!Directory.Exists(ordner))
        {
            return [];
        }

        return Dateien(ordner)
            .Select(LiesDatei)
            .OfType<ArbeitsplatzEintrag>()
            .Where(eintrag => !string.Equals(
                eintrag.Rechnername, DieserRechner, StringComparison.OrdinalIgnoreCase))
            .GroupBy(eintrag => eintrag.Rechnername, StringComparer.OrdinalIgnoreCase)
            .Select(gruppe => gruppe.MaxBy(eintrag => eintrag.ZuletztGearbeitet)!)
            .ToList();
    }

    /// <summary>
    /// Hält fest, dass hier gerade gearbeitet wird, ohne den gesicherten Stand
    /// anzurühren. Beides gehört zusammen und darf sich doch nicht vermischen:
    /// Wer die App nur kurz öffnet, hat gearbeitet — gesichert hat er nichts.
    /// </summary>
    public static void MerkeArbeitsbeginn(string ordner)
    {
        var bisher = LiesEigene(ordner);
        Schreibe(ordner, new ArbeitsplatzEintrag(
            DieserRechner,
            DateTime.Now,
            bisher?.GesichertAm,
            bisher?.Sicherung,
            Programmfassung.Aktuell));
    }

    /// <summary>
    /// Hält fest, dass der Stand dieses Rechners als Archiv abgelegt wurde —
    /// der Zeitpunkt, an dem sich das Übernahme-Angebot der anderen entscheidet.
    /// </summary>
    public static void MerkeSicherung(string ordner, DateTime zeitpunkt, string datei) =>
        Schreibe(ordner, new ArbeitsplatzEintrag(
            DieserRechner, zeitpunkt, zeitpunkt, datei, Programmfassung.Aktuell));

    /// <summary>
    /// Hält fest, dass dieser Rechner den Stand eines anderen übernommen hat:
    /// gearbeitet wird <em>jetzt</em>, der Stand ist aber der von damals.
    ///
    /// Genau diese Trennung verhindert die Endlosschleife: Ohne den übernommenen
    /// <paramref name="gesichertAm"/> böte jeder Start dasselbe Archiv erneut
    /// an; mit dem Zeitpunkt von jetzt sähe der andere Arbeitsplatz einen
    /// vermeintlich neueren Stand und böte ihn zurück.
    /// </summary>
    public static void MerkeUebernahme(string ordner, DateTime gesichertAm, string datei) =>
        Schreibe(ordner, new ArbeitsplatzEintrag(
            DieserRechner, DateTime.Now, gesichertAm, datei, Programmfassung.Aktuell));

    /// <summary>
    /// Schreibt die Akte dieses Rechners. Der Ordner wird angelegt, falls er
    /// fehlt — beim ersten Mal existiert er noch nicht.
    /// </summary>
    public static void Schreibe(string ordner, ArbeitsplatzEintrag eintrag)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(ordner);
        ArgumentNullException.ThrowIfNull(eintrag);

        var zwischenstand = Path.Combine(
            Path.GetTempPath(), $"arbeitsplatz-{Guid.NewGuid():N}.json");
        File.WriteAllText(zwischenstand, JsonSerializer.Serialize(eintrag, Format));
        AtomareAblage.Ersetze(
            zwischenstand, Path.Combine(ordner, DateinameFuer(eintrag.Rechnername)));
    }

    static IEnumerable<string> Dateien(string ordner)
    {
        try
        {
            return Directory.EnumerateFiles(ordner, Suchmuster, SearchOption.TopDirectoryOnly);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            // Ordner getrennt, Rechte weg: kein Angebot statt eines Abbruchs.
            return [];
        }
    }

    static ArbeitsplatzEintrag? LiesDatei(string pfad)
    {
        try
        {
            var eintrag = JsonSerializer.Deserialize<ArbeitsplatzEintrag>(
                File.ReadAllText(pfad), Format);
            // Ohne Rechnernamen laesst sich der Eintrag niemandem zuordnen —
            // eigener oder fremder Stand waere geraten.
            return string.IsNullOrWhiteSpace(eintrag?.Rechnername) ? null : eintrag;
        }
        catch (Exception ex) when (
            ex is JsonException or IOException or UnauthorizedAccessException or ArgumentException)
        {
            return null;
        }
    }

    /// <summary>
    /// Macht aus einem Rechnernamen einen Dateinamensteil. Windows-Rechnernamen
    /// sind ohnehin harmlos; die Sicherung gilt dem Fall, in dem ein Eintrag von
    /// Hand verändert wurde und ein Pfadtrenner darin steht.
    /// </summary>
    static string Bereinige(string rechnername)
    {
        var sauber = new string((rechnername ?? string.Empty)
            .Select(z => Path.GetInvalidFileNameChars().Contains(z) ? '-' : z)
            .ToArray())
            .Trim();
        return sauber.Length > 0 ? sauber : "unbekannt";
    }
}
