namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Erkennt einen neueren Stand am anderen Arbeitsplatz und übernimmt ihn auf
/// Wunsch (§7.2, #39). Siehe <see cref="IArbeitsplatzUebergabe"/>.
///
/// <para>
/// <b>Woran sich das Angebot entscheidet.</b> An <c>GesichertAm</c>, nicht an
/// <c>ZuletztGearbeitet</c>: Übernehmen lässt sich nur, was als Archiv dasteht.
/// Und nur, wenn dieses Archiv im Ordner wirklich liegt — die Akte kann bereits
/// synchronisiert sein, während das Archiv daneben noch überträgt. Ein Angebot
/// auf eine Datei, die es nicht gibt, wäre eine Frage, deren Ja ins Leere geht.
/// </para>
///
/// <para>
/// <b>Was das Verfahren nicht kann.</b> Es ist eine Übergabe, keine
/// Verschmelzung: Wer übernimmt, ersetzt seinen Stand. Zwei Arbeitsplätze, die
/// am selben Tag beide arbeiten, führt niemand zusammen — dagegen hilft die
/// Frage selbst (sie nennt Rechner und Zeitpunkt) und die Sicherung, die der
/// Import vorher vom bisherigen Stand anlegt.
/// </para>
/// </summary>
/// <param name="sicherung">Spielt das Archiv ein — derselbe Weg wie von Hand.</param>
/// <param name="merker">Der Ausgang der letzten automatischen Sicherung.</param>
/// <param name="ablageOrdner">Der eingestellte Ordner, je Aufruf neu gelesen.</param>
/// <param name="logger">Hält die Übernahme fest — sie ersetzt den Bestand.</param>
public sealed class ArbeitsplatzUebergabe(
    IDatabaseBackupService sicherung,
    LetzteSicherungAkte merker,
    Func<string> ablageOrdner,
    ILogger<ArbeitsplatzUebergabe> logger) : IArbeitsplatzUebergabe
{
    public UebergabeStand Stand()
    {
        var ordner = ablageOrdner();
        var letzterLauf = merker.Lies();
        if (ordner.Length == 0)
        {
            return new UebergabeStand(null, null, letzterLauf, string.Empty);
        }

        var eigener = ArbeitsplatzAkte.LiesEigene(ordner);
        return new UebergabeStand(SucheAngebot(ordner, eigener), eigener, letzterLauf, ordner);
    }

    public async Task<UebernahmeErgebnis> UebernehmenAsync(
        CancellationToken cancellationToken = default)
    {
        var ordner = ablageOrdner();
        if (ordner.Length == 0)
        {
            return UebernahmeErgebnis.KeinAngebot;
        }

        // Bewusst neu ermittelt statt aus der Anzeige uebernommen: Zwischen der
        // Frage auf dem Bildschirm und dem Klick kann der Ordner ein anderer
        // sein. Uebernommen wird, was jetzt dasteht.
        var angebot = SucheAngebot(ordner, ArbeitsplatzAkte.LiesEigene(ordner));
        if (angebot?.Sicherung is null || angebot.GesichertAm is null)
        {
            return UebernahmeErgebnis.KeinAngebot;
        }

        var archiv = Path.Combine(ordner, angebot.Sicherung);
        SicherungsImportErgebnis ergebnis;
        await using (var strom = File.OpenRead(archiv))
        {
            ergebnis = await sicherung.ImportBackupAsync(strom, cancellationToken);
        }

        ArbeitsplatzAkte.MerkeUebernahme(ordner, angebot.GesichertAm.Value, angebot.Sicherung);
        logger.LogInformation(
            "Stand von {Rechner} vom {Zeitpunkt} uebernommen ({Datei}).",
            angebot.Rechnername, angebot.GesichertAm, angebot.Sicherung);
        return new UebernahmeErgebnis(angebot.Rechnername, ergebnis.UebersprungeneVorlagen);
    }

    public void QuittiereFehler() => merker.Quittiere();

    /// <summary>
    /// Der neueste fremde Stand, der neuer ist als der eigene und als Datei
    /// dasteht. Hat dieser Rechner noch nie gesichert, zählt jeder fremde Stand
    /// — das ist der Fall „App auf dem zweiten Rechner zum ersten Mal geöffnet",
    /// für den das Ganze gebaut ist.
    /// </summary>
    static ArbeitsplatzEintrag? SucheAngebot(string ordner, ArbeitsplatzEintrag? eigener)
    {
        var eigenerStand = eigener?.GesichertAm;
        return ArbeitsplatzAkte.LiesFremde(ordner)
            .Where(fremd => fremd.GesichertAm is not null
                            && !string.IsNullOrWhiteSpace(fremd.Sicherung)
                            && (eigenerStand is null || fremd.GesichertAm > eigenerStand)
                            && File.Exists(Path.Combine(ordner, fremd.Sicherung)))
            .MaxBy(fremd => fremd.GesichertAm);
    }
}
