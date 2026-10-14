namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Der veränderliche Stand hinter dem <see cref="AktualisierungsDienst"/> (#196).
/// Nicht threadsicher: Jeder Zugriff geschieht unter der Sperre des Dienstes;
/// nach außen geht der Stand nur als unveränderliche <see cref="Momentaufnahme"/>.
///
/// Hier wohnt die Regel zu <c>fehlerArt</c>: <see cref="AktualisierungsZustand.Fehler"/>
/// gibt es nur mit Ursache (<see cref="SetzeFehler"/>), jeder andere Zustand
/// trägt keine.
/// </summary>
/// <param name="laufendeVersion">Wie <c>/health</c> sie meldet.</param>
public sealed class AktualisierungsLage(string laufendeVersion)
{
    private AktualisierungsFehlerArt? _fehlerArt;
    private long _geladen;

    public AktualisierungsZustand Zustand { get; private set; } = AktualisierungsZustand.Unbekannt;

    public SetupAuswahlErgebnis? Auswahl { get; private set; }

    public string? Meldung { get; private set; }

    /// <summary>Aus der Merkdatei, bis das Frontend quittiert.</summary>
    public LetzteAktualisierung? Letzte { get; set; }

    public bool LaeuftOderBereit => Zustand is AktualisierungsZustand.Laedt or AktualisierungsZustand.Bereit;

    /// <summary>Ein Zustand ohne Ursache; nach <see cref="AktualisierungsZustand.Fehler"/> geht es nur über <see cref="SetzeFehler"/>.</summary>
    public void Setze(AktualisierungsZustand zustand, SetupAuswahlErgebnis? auswahl, string? meldung = null)
    {
        if (zustand == AktualisierungsZustand.Fehler)
        {
            throw new ArgumentException("Den Fehlerzustand gibt es nur mit Ursache (SetzeFehler).", nameof(zustand));
        }

        Uebernimm(zustand, auswahl, meldung, null);
    }

    public void SetzeFehler(SetupAuswahlErgebnis? auswahl, AktualisierungsFehler fehler)
    {
        ArgumentNullException.ThrowIfNull(fehler);
        Uebernimm(AktualisierungsZustand.Fehler, auswahl, fehler.Meldung, fehler.Art);
    }

    /// <summary>Das Ergebnis einer Prüfung: aktuell, verfügbar — oder ein Fehler samt Ursache.</summary>
    public void Bewerte(SetupAuswahlErgebnis auswahl)
    {
        ArgumentNullException.ThrowIfNull(auswahl);
        var (zustand, fehler) = auswahl.Bewertung();
        if (fehler is null)
        {
            Setze(zustand, auswahl);
        }
        else
        {
            SetzeFehler(auswahl, fehler);
        }
    }

    /// <summary>Geladen und geprüft; die Auswahl bleibt.</summary>
    public void Bereit(long groesse)
    {
        Zustand = AktualisierungsZustand.Bereit;
        _geladen = groesse;
    }

    public void MeldeFortschritt(long geschrieben)
    {
        if (Zustand == AktualisierungsZustand.Laedt)
        {
            _geladen = geschrieben;
        }
    }

    public AktualisierungsStand Momentaufnahme() => new(
        laufendeVersion,
        Auswahl?.NeueVersion?.ToString(),
        Zustand,
        _geladen,
        Auswahl?.Setup?.Groesse,
        Meldung,
        _fehlerArt,
        Auswahl?.DownloadUrl,
        Letzte);

    private void Uebernimm(
        AktualisierungsZustand zustand,
        SetupAuswahlErgebnis? auswahl,
        string? meldung,
        AktualisierungsFehlerArt? fehlerArt)
    {
        Zustand = zustand;
        Auswahl = auswahl;
        Meldung = meldung;
        _fehlerArt = fehlerArt;
        _geladen = 0;
    }
}
