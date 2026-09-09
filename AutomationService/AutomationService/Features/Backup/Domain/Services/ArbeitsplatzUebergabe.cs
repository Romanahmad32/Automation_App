
namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>Vergleicht die Herkunft der Stände, prüft die Übertragung und übernimmt nur die bestätigte Fassung.</summary>
public sealed class ArbeitsplatzUebergabe(
    IDatabaseBackupService sicherung,
    LetzteSicherungAkte merker,
    Func<string> ablageOrdner,
    ILogger<ArbeitsplatzUebergabe> logger) : IArbeitsplatzUebergabe
{
    SynchronisationsVerlauf? Verlauf => (sicherung as DatabaseBackupService)?.Verlauf;

    public UebergabeStand Stand()
    {
        var ordner = ablageOrdner();
        if (ordner.Length == 0)
        {
            return new(null, null, merker.Lies(), ordner, SicherungsBestand.Leer)
            {
                Zustand = "nichtEingerichtet",
                Hinweis = "Für den Arbeitsplatzwechsel in den Einstellungen einen gemeinsamen OneDrive-App-Datenordner wählen.",
            };
        }

        try
        {
            var stand = Ermittle(ordner);
            return Verlauf?.Aktivitaet is { } aktivitaet
                ? stand with { Zustand = aktivitaet } : stand;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or System.Text.Json.JsonException)
        {
            return new(null, null, merker.Lies(), ordner, SicherungsBestand.Leer)
            {
                Zustand = "nichtErreichbar",
                Hinweis = "Der Synchronisationsstand ist nicht prüfbar. Bitte OneDrive und den Ablageordner prüfen. " + ex.Message,
            };
        }
    }

    UebergabeStand Ermittle(string ordner)
    {
        var lokal = Verlauf?.Lies();
        var eigener = lokal?.Eintrag ?? ArbeitsplatzAkte.LiesEigene(ordner);
        var fremde = ArbeitsplatzAkte.LiesFremde(ordner);
        var kandidaten = fremde.Where(f => UebergabePruefung.IstFremderStand(f, eigener)).ToList();
        // Bei einer Kette zählt der Nachfolger unabhängig von der Uhrzeit des Rechners.
        var enden = kandidaten.Where(f => f.Revision is null || !kandidaten.Any(n => n.Vorfahren.Contains(f.Revision))).ToList();
        var bereit = enden.Where(f => UebergabePruefung.Vollstaendig(ordner, f)).ToList();
        var angebot = bereit.MaxBy(f => f.GesichertAm);
        var inhalt = Verlauf?.Fingerabdruck();
        var geaendert = lokal is null || lokal.Fingerabdruck != inhalt;
        var konflikt = angebot is not null && (enden.Count > 1 || UebergabePruefung.Konflikt(angebot, lokal, geaendert));
        var empfangen = eigener?.Revision is not null && fremde.Any(f => f.Revision == eigener.Revision
            || f.Vorfahren.Contains(eigener.Revision));
        var zustand = !Directory.Exists(ordner) ? "nichtErreichbar"
            : konflikt ? "konflikt" : angebot is not null ? "angebot"
            : enden.Count > 0 ? "warten" : geaendert ? "geaendert" : "bereit";
        var hinweis = zustand switch
        {
            "nichtErreichbar" => "Der gemeinsame Ordner ist nicht erreichbar. Bitte OneDrive prüfen.",
            "konflikt" => "Auf den Rechnern liegen unterschiedliche Änderungen vor. Eine Übernahme ersetzt die hiesigen Daten; beide Stände werden nicht zusammengeführt.",
            "angebot" => $"Ein Datenstand von {angebot!.Rechnername} liegt zur Prüfung und Übernahme bereit.",
            "warten" => "Ein anderer Rechner hat einen Stand bereitgestellt. Die Sicherungsdatei ist hier noch nicht vollständig angekommen. OneDrive wird erneut geprüft.",
            "geaendert" => "Die Daten sind lokal gespeichert. Änderungen werden spätestens nach 30 Minuten, beim Vorgangsabschluss und beim Beenden bereitgestellt.",
            _ => empfangen ? "Der bereitgestellte Datenstand wurde am anderen Rechner übernommen."
                : "Der Datenstand liegt im gemeinsamen Ordner. Ob OneDrive den Upload abgeschlossen hat, kann die App nicht bestätigen.",
        };
        return new(angebot, eigener, merker.Lies(), ordner, SicherungsBestand.Lies(ordner, ArbeitsplatzAkte.DieserRechner))
        {
            Zustand = zustand,
            Hinweis = hinweis,
            Konflikt = konflikt,
            LokaleAenderungen = geaendert,
            Pruefkennung = angebot is null ? null : UebergabePruefung.Kennung(angebot, inhalt),
        };
    }

    public async Task<UebernahmeErgebnis> UebernehmenAsync(CancellationToken cancellationToken = default) =>
        await UebernehmenGeprueftAsync(null, false, cancellationToken);

    public async Task<UebernahmeErgebnis> UebernehmenGeprueftAsync(
        string? pruefkennung, bool konfliktBestaetigt, CancellationToken cancellationToken = default)
    {
        await SynchronisationsVerlauf.Schleuse.WaitAsync(cancellationToken);
        try
        {
            var stand = Stand();
            var angebot = stand.Angebot;
            if (angebot?.Sicherung is null || angebot.GesichertAm is null)
                return UebernahmeErgebnis.KeinAngebot;
            if (pruefkennung != stand.Pruefkennung && (pruefkennung is not null || angebot.Revision is not null)
                || stand.Konflikt && !konfliktBestaetigt)
            {
                throw new InvalidBackupException("Der angebotene Stand oder die lokalen Daten haben sich geändert. Bitte erneut prüfen und bestätigen.");
            }

            var inhalt = Verlauf?.Fingerabdruck();
            if (UebergabePruefung.Kennung(angebot, inhalt) != stand.Pruefkennung)
            {
                throw new InvalidBackupException("Der lokale Stand hat sich geändert. Bitte erneut prüfen und bestätigen.");
            }
            if (Verlauf is { } aktiv) aktiv.Aktivitaet = "uebernehmen";
            SicherungsImportErgebnis ergebnis;
            await using (var strom = File.OpenRead(Path.Combine(stand.AblageOrdner, angebot.Sicherung)))
            {
                UebergabePruefung.PruefeStream(strom, angebot);
                ergebnis = sicherung is DatabaseBackupService dienst
                    ? await dienst.ImportGeprueftAsync(strom, inhalt, angebot, cancellationToken)
                    : await sicherung.ImportBackupAsync(strom, cancellationToken);
            }
            // Die lokale Quittung ist bereits beim Import gespeichert. Eine Cloud-Störung
            // danach darf die erfolgreiche Übernahme nicht als fehlgeschlagen melden.
            try
            {
                ArbeitsplatzAkte.Schreibe(stand.AblageOrdner, angebot with
                { Rechnername = ArbeitsplatzAkte.DieserRechner, ZuletztGearbeitet = DateTime.Now });
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                logger.LogWarning(ex, "Übernahme gelungen, Empfangsbestätigung noch nicht im gemeinsamen Ordner.");
            }
            return new(angebot.Rechnername, ergebnis.UebersprungeneVorlagen);
        }
        finally { if (Verlauf is { } aktiv) aktiv.Aktivitaet = null; SynchronisationsVerlauf.Schleuse.Release(); }
    }

    public void QuittiereFehler() => merker.Quittiere();
}
