namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>Was die Prüfung über das neueste Release ergeben hat.</summary>
public enum AuswahlArt
{
    /// <summary>Nicht neuer als die laufende Version — oder eine der beiden unlesbar.</summary>
    KeinUpdate,

    /// <summary>Neuer, mit genau einer passenden Setup-Datei samt Größe und Prüfsumme.</summary>
    Verfuegbar,

    /// <summary>Neuer, die Setup-Datei ist da, aber ohne gültige Größe oder <c>digest</c>.</summary>
    OhnePruefsumme,

    /// <summary>Neuer, aber keine (oder keine eindeutige) passende Setup-Datei.</summary>
    OhneSetup,
}

/// <summary>Die Setup-Datei, die heruntergeladen werden darf.</summary>
/// <param name="Version">Die Version aus Tag und Dateiname — beide gleich.</param>
/// <param name="Adresse">Der direkte Download.</param>
/// <param name="Groesse">Bytes laut API.</param>
/// <param name="Sha256">Kleingeschriebenes Hex, 64 Zeichen.</param>
public sealed record SetupDatei(Versionsnummer Version, Uri Adresse, long Groesse, string Sha256);

/// <summary>Ergebnis von <see cref="SetupAuswahl.Waehle"/>.</summary>
/// <param name="Art">Was die Prüfung ergab.</param>
/// <param name="NeueVersion">Gesetzt, sobald das Release neuer ist.</param>
/// <param name="Setup">Nur bei <see cref="AuswahlArt.Verfuegbar"/> gesetzt.</param>
/// <param name="DownloadUrl">
/// Der Rückfallweg „Lieber selbst herunterladen" — auch dann gesetzt, wenn die
/// Prüfsumme fehlt: Der Dienst lädt keine Datei, die er nicht prüfen kann, der
/// Anwender darf es auf eigenen Entschluss. Nur eine <c>https://github.com/…</c>-Adresse
/// (<see cref="SetupAuswahl.FuerDenBrowser"/>), sonst <c>null</c>.
/// </param>
public sealed record SetupAuswahlErgebnis(
    AuswahlArt Art,
    Versionsnummer? NeueVersion,
    SetupDatei? Setup,
    string? DownloadUrl)
{
    public static readonly SetupAuswahlErgebnis KeinUpdate = new(AuswahlArt.KeinUpdate, null, null, null);

    /// <summary>
    /// Was der Anwender nach der Prüfung sieht: Zustand und, wo nötig, warum
    /// nicht geladen wird. Für beide Fälle gibt es keinen kurzen Satz im
    /// Dialog — nur die Meldung sagt, dass es an der Veröffentlichung liegt.
    /// </summary>
    public (AktualisierungsZustand Zustand, AktualisierungsFehler? Fehler) Bewertung() => Art switch
    {
        AuswahlArt.KeinUpdate => (AktualisierungsZustand.Aktuell, null),
        AuswahlArt.Verfuegbar => (AktualisierungsZustand.Verfuegbar, null),
        AuswahlArt.OhnePruefsumme => (AktualisierungsZustand.Fehler,
            new AktualisierungsFehler(AktualisierungsFehlerArt.Sonstig, AktualisierungsMeldungen.OhnePruefsumme(NeueVersion))),
        _ => (AktualisierungsZustand.Fehler,
            new AktualisierungsFehler(AktualisierungsFehlerArt.Sonstig, AktualisierungsMeldungen.OhneSetup(NeueVersion))),
    };
}
