namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Was der Anwender liest, wenn etwas nicht geht (#196). Jede Meldung sagt,
/// was passiert ist und was er tun kann — für jemanden, der Angst hat, beim
/// Aktualisieren etwas kaputtzumachen. Kein Fachwort ohne Not, kein Stacktrace.
/// </summary>
public static class AktualisierungsMeldungen
{
    public const string NichtGeprueft =
        "Ob es eine neue Version gibt, ließ sich gerade nicht prüfen — vermutlich besteht keine "
        + "Verbindung ins Internet. Die App funktioniert unverändert weiter.";

    /// <summary>
    /// GitHubs Ratenlimit (<see cref="QuelleAusgelastetException"/>, #199): Die Leitung steht,
    /// nur nimmt GitHub gerade keine Anfrage an. Wieder geprüft wird beim nächsten Start der
    /// App — das tut sie von selbst, früher nicht; mehr verspricht der Satz deshalb nicht.
    /// </summary>
    public const string Ausgelastet =
        "Ob es eine neue Version gibt, ließ sich gerade nicht prüfen — der Update-Server ist im "
        + "Moment ausgelastet. Die App sieht beim nächsten Start wieder nach und funktioniert "
        + "unverändert weiter.";

    /// <summary>Die Meldung zu einer Prüfung, die nicht ging — nie der Text der Ausnahme.</summary>
    public static string NachGescheiterterPruefung(Exception ausnahme) =>
        ausnahme is QuelleAusgelastetException ? Ausgelastet : NichtGeprueft;

    public const string KeineNeueVersion =
        "Es ist keine neue Version bekannt, die heruntergeladen werden könnte. Bitte zuerst nach "
        + "Aktualisierungen suchen.";

    public const string NichtBereit =
        "Die neue Version ist noch nicht vollständig heruntergeladen und geprüft.";

    public const string Unterbrochen =
        "Der Download wurde unterbrochen — vermutlich ist die Internetverbindung abgerissen. "
        + "Bitte noch einmal versuchen.";

    public const string Stockt =
        "Der Download kam nicht mehr voran und wurde abgebrochen. Bitte noch einmal versuchen.";

    public const string NichtGespeichert =
        "Die Datei ließ sich nicht speichern (ist die Festplatte voll?). Bitte noch einmal versuchen.";

    public const string StartGescheitert =
        "Das Installationsprogramm ließ sich nicht starten. Bitte die Datei über „Lieber selbst "
        + "herunterladen“ laden und von Hand ausführen.";

    /// <summary>
    /// Das Setup endete binnen der Anlauffrist (<see cref="InstallerStart.Anlauffrist"/>), also
    /// bevor es etwas ersetzt hat. Der Satz erscheint im Dialog 2d (<c>fehlerArt</c> <c>sonstig</c>)
    /// über „Es wurde nichts verändert.“ — das stimmt hier. Nicht zu verwechseln mit 3c: Scheitert
    /// ein Update erst später, meldet das der nächste Start aus der Merkdatei, als Rückmeldung
    /// <c>AktualisierungsBegleiter.fehlerText</c> im Frontend; dort kann schon etwas ersetzt sein,
    /// und dieser Dienst liefert dafür keinen Satz.
    /// </summary>
    public const string SofortBeendet =
        "Das Installationsprogramm hat sich sofort wieder beendet — vielleicht läuft gerade schon "
        + "eine Installation. Bitte in ein paar Minuten noch einmal versuchen.";

    /// <summary>Ein Dienst außerhalb der installierten App (<see cref="InstallerStarter.Sperrgrund"/>).</summary>
    public const string NurInstalliert =
        "Installieren geht nur aus der installierten App. Dieser Dienst läuft in der "
        + "Entwicklungsumgebung und startet kein Installationsprogramm.";

    public static string OhneSetup(Versionsnummer? version) =>
        $"Version {version} ist erschienen, die Setup-Datei dazu ist aber noch nicht abrufbar. "
        + "Bitte später noch einmal versuchen.";

    public static string OhnePruefsumme(Versionsnummer? version) =>
        $"Version {version} ist erschienen, lässt sich aber nicht sicher prüfen, weil die "
        + "Prüfsumme fehlt. Deshalb lädt die App sie nicht selbst. Sie können die Datei über "
        + "„Lieber selbst herunterladen“ laden.";

    /// <summary>Die Meldung zu einer gescheiterten Prüfung; die Datei ist dann schon gelöscht.</summary>
    public static string Fuer(SetupPruefErgebnis ergebnis) => ergebnis switch
    {
        SetupPruefErgebnis.Fehlt =>
            "Die heruntergeladene Datei ist nicht mehr vorhanden. Bitte noch einmal herunterladen.",
        SetupPruefErgebnis.GroesseFalsch =>
            "Die heruntergeladene Datei ist unvollständig und wurde gelöscht. Bitte noch einmal versuchen.",
        _ =>
            "Die heruntergeladene Datei stimmt nicht mit der veröffentlichten überein und wurde "
            + "gelöscht. Bitte noch einmal versuchen oder die Datei selbst herunterladen.",
    };
}
