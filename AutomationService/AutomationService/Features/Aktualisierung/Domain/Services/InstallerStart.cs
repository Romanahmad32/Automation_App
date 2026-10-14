namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Der letzte Schritt vor dem Installer (#196): Datei erneut prüfen,
/// Merkdatei schreiben, Installer starten — in dieser Reihenfolge, und mit
/// der Datei die ganze Zeit offen und gegen Schreiben gesperrt. Zwischen
/// Prüfung und Start kann sie so niemand austauschen. Danach noch die
/// <see cref="Anlauffrist"/>: Erst ein Setup, das sie übersteht, gilt als laufend.
/// </summary>
public static class InstallerStart
{
    /// <summary>
    /// So lange sieht der Dienst nach dem Start hin, ob sich das Setup gleich
    /// wieder beendet — etwa weil schon ein zweites läuft (<c>SetupMutex</c>,
    /// im stillen Lauf ohne Rückfrage) oder ein Virenscanner es abbricht. Ein
    /// Setup, das arbeitet, endet nie so schnell: Es wartet in
    /// <c>InitializeSetup</c> auf das Ende des Dienstes, und der fährt erst
    /// nach dieser Frist herunter. Die Antwort auf <c>POST installieren</c>
    /// kommt deshalb im Normalfall nach genau drei Sekunden.
    /// </summary>
    public static readonly TimeSpan Anlauffrist = TimeSpan.FromSeconds(3);

    /// <returns><c>null</c>, wenn der Installer läuft; sonst Ursache und Meldung für den Anwender.</returns>
    public static AktualisierungsFehler? PruefeUndStarte(
        SetupDatei setup,
        AktualisierungsOrdner ordner,
        Merkdatei merkdatei,
        IInstallerStarter starter,
        TimeProvider zeit,
        ILogger logger)
    {
        ArgumentNullException.ThrowIfNull(setup);
        ArgumentNullException.ThrowIfNull(ordner);
        ArgumentNullException.ThrowIfNull(merkdatei);
        ArgumentNullException.ThrowIfNull(starter);
        ArgumentNullException.ThrowIfNull(zeit);

        var pfad = ordner.SetupPfad(setup.Version);
        SetupPruefErgebnis pruefung;
        IInstallerLauf? lauf = null;
        try
        {
            using var gesperrt = new FileStream(pfad, FileMode.Open, FileAccess.Read, FileShare.Read);
            pruefung = SetupPruefung.Pruefe(gesperrt, setup);
            if (pruefung == SetupPruefErgebnis.InOrdnung)
            {
                // Die Merkdatei zuerst: Startet der Installer, beendet sich die
                // App gleich danach — ohne Zettel wüsste der nächste Start nicht,
                // dass er ein Ergebnis zu melden hat.
                merkdatei.Schreibe(new Merkzettel(setup.Version.ToString(), zeit.GetLocalNow()));
                lauf = starter.Starte(InstallerAufruf.Fuer(pfad, ordner.LogPfad(setup.Version), ordner.Pfad, setup.Version));
            }
        }
        catch (Exception ausnahme) when (ausnahme is FileNotFoundException or DirectoryNotFoundException)
        {
            pruefung = SetupPruefErgebnis.Fehlt;
        }
        catch (Exception ausnahme)
        {
            // Merkdatei nicht schreibbar, Start verweigert (Virenscanner,
            // Richtlinie): Es läuft kein Setup, also gibt es nichts zu melden.
            logger.LogWarning(ausnahme, "Der Installer für {Version} ließ sich nicht starten.", setup.Version);
            merkdatei.Loesche();
            return new AktualisierungsFehler(AktualisierungsFehlerArt.Sonstig, AktualisierungsMeldungen.StartGescheitert);
        }

        // Gewartet wird nach dem Freigeben der Datei: Gegen Austausch muss sie
        // nur bis zum Start geschützt sein.
        if (lauf is not null)
        {
            return PruefeAnlauf(lauf, setup.Version, merkdatei, logger);
        }

        logger.LogWarning("Die Setup-Datei {Version} hat die zweite Prüfung nicht bestanden: {Ergebnis}", setup.Version, pruefung);
        try
        {
            File.Delete(pfad);
        }
        catch (Exception ausnahme) when (ausnahme is IOException or UnauthorizedAccessException)
        {
            logger.LogInformation(ausnahme, "Die verworfene Setup-Datei bleibt bis zum nächsten Start liegen.");
        }

        return AktualisierungsFehler.Zu(pruefung);
    }

    /// <summary>
    /// Endet das Setup binnen <see cref="Anlauffrist"/>, hat es nichts
    /// installiert — die Merkdatei kommt weg, und der Aufrufer fährt den Dienst
    /// nicht herunter. Die Setup-Datei bleibt liegen; sie ist ja geprüft.
    /// </summary>
    private static AktualisierungsFehler? PruefeAnlauf(
        IInstallerLauf lauf,
        Versionsnummer version,
        Merkdatei merkdatei,
        ILogger logger)
    {
        int? rueckgabewert;
        using (lauf)
        {
            rueckgabewert = lauf.WarteAufEnde(Anlauffrist);
        }

        if (rueckgabewert is not { } code)
        {
            return null;
        }

        logger.LogWarning(
            "Der Installer für {Version} hat sich sofort wieder beendet (Rückgabewert {Rueckgabewert}); der Dienst bleibt an.",
            version,
            code);
        merkdatei.Loesche();
        return new AktualisierungsFehler(AktualisierungsFehlerArt.Sonstig, AktualisierungsMeldungen.SofortBeendet);
    }
}
