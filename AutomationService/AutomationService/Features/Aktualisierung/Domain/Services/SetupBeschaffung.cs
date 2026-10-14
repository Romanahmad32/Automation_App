namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Ein Download der Setup-Datei von Anfang bis Ende (#196): in die Teildatei
/// laden (<see cref="SetupDownload"/>), Größe und SHA256 prüfen
/// (<see cref="SetupPruefung"/>), erst dann unter dem richtigen Namen ablegen.
/// Eine Setup-Datei ohne <c>.part</c> ist damit immer eine geprüfte; was die
/// Prüfung nicht besteht, ist danach gelöscht.
///
/// Ohne eigenen Zustand: Was der Anwender sieht, setzt
/// <see cref="AktualisierungsDienst"/> aus dem Ergebnis.
/// </summary>
public static class SetupBeschaffung
{
    /// <returns><c>null</c>, wenn die geprüfte Datei bereitliegt; sonst Ursache und Meldung für den Anwender.</returns>
    /// <exception cref="OperationCanceledException">
    /// Abgebrochen über <paramref name="abbruch"/>; die Teildatei ist dann schon gelöscht.
    /// </exception>
    public static async Task<AktualisierungsFehler?> LadeUndPruefeAsync(
        IAktualisierungsQuelle quelle,
        SetupDatei setup,
        AktualisierungsOrdner ordner,
        TimeSpan leerlauf,
        Action<long> fortschritt,
        ILogger logger,
        CancellationToken abbruch,
        TimeProvider? zeit = null)
    {
        ArgumentNullException.ThrowIfNull(setup);
        ArgumentNullException.ThrowIfNull(ordner);
        ArgumentNullException.ThrowIfNull(logger);

        var ziel = ordner.SetupPfad(setup.Version);
        var teil = AktualisierungsOrdner.Teildatei(ziel);
        AktualisierungsFehler fehler;
        try
        {
            Directory.CreateDirectory(ordner.Pfad);
            await SetupDownload.LadeAsync(quelle, setup, teil, leerlauf, fortschritt, abbruch, zeit);

            var pruefung = SetupPruefung.Pruefe(teil, setup);
            if (pruefung == SetupPruefErgebnis.InOrdnung)
            {
                await KurzeSperre.WiederholeAsync(
                    () =>
                    {
                        File.Move(teil, ziel, overwrite: true);
                        return true;
                    },
                    abbruch);
                return null;
            }

            logger.LogWarning("Die Setup-Datei {Version} hat die Prüfung nicht bestanden: {Ergebnis}", setup.Version, pruefung);
            fehler = AktualisierungsFehler.Zu(pruefung);
        }
        catch (OperationCanceledException) when (abbruch.IsCancellationRequested)
        {
            LoescheStill(teil, logger);
            throw;
        }
        catch (Exception ausnahme)
        {
            logger.LogWarning(ausnahme, "Der Download der Setup-Datei {Version} ist gescheitert.", setup.Version);
            fehler = FehlerZu(ausnahme);
        }

        LoescheStill(teil, logger);
        return fehler;
    }

    /// <summary>Ursache und Meldung zu einem gescheiterten Download — nie der Text der Ausnahme.</summary>
    public static AktualisierungsFehler FehlerZu(Exception ausnahme) => ausnahme switch
    {
        TimeoutException => new(AktualisierungsFehlerArt.Verbindung, AktualisierungsMeldungen.Stockt),
        // Mehr Bytes als angekündigt: verworfen wie eine falsche Prüfsumme.
        InvalidDataException => AktualisierungsFehler.Zu(SetupPruefErgebnis.PruefsummeFalsch),
        UnauthorizedAccessException => new(AktualisierungsFehlerArt.Sonstig, AktualisierungsMeldungen.NichtGespeichert),
        // ERROR_SHARING_VIOLATION und ERROR_LOCK_VIOLATION (die Teildatei hält
        // dauerhaft ein Virenscanner), ERROR_HANDLE_DISK_FULL und
        // ERROR_DISK_FULL; jeder andere E/A-Fehler kommt hier vom Netz
        // (HttpIOException ist eine IOException).
        IOException io when (io.HResult & 0xFFFF) is 0x20 or 0x21 or 0x27 or 0x70 =>
            new(AktualisierungsFehlerArt.Sonstig, AktualisierungsMeldungen.NichtGespeichert),
        _ => new(AktualisierungsFehlerArt.Verbindung, AktualisierungsMeldungen.Unterbrochen),
    };

    private static void LoescheStill(string pfad, ILogger logger)
    {
        try
        {
            File.Delete(pfad);
        }
        catch (Exception ausnahme) when (ausnahme is IOException or UnauthorizedAccessException)
        {
            logger.LogInformation(ausnahme, "Teildatei {Datei} bleibt bis zum nächsten Start liegen.", pfad);
        }
    }
}
