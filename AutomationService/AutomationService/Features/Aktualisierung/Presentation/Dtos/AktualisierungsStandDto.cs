using AutomationService.Features.Aktualisierung.Domain.Services;

namespace AutomationService.Features.Aktualisierung.Presentation.Dtos;

/// <summary>
/// Antwort aller Endpunkte unter <c>api/Aktualisierung</c> (#196).
/// <see cref="Zustand"/> ist <c>unbekannt</c>, <c>aktuell</c>,
/// <c>verfuegbar</c>, <c>laedt</c>, <c>bereit</c> oder <c>fehler</c>.
/// </summary>
/// <param name="LaufendeVersion">Wie <c>GET /health</c> sie meldet.</param>
/// <param name="NeueVersion">Dreistellig ohne <c>v</c>, sobald eine neuere bekannt ist.</param>
/// <param name="Zustand">Siehe oben.</param>
/// <param name="GeladenBytes">Fortschritt des Downloads; bei <c>bereit</c> gleich <see cref="GesamtBytes"/>.</param>
/// <param name="GesamtBytes">Größe der Setup-Datei laut GitHub, sobald eine ladbare bekannt ist.</param>
/// <param name="Meldung">Deutsch, für den Anwender — bei <c>fehler</c> immer, bei <c>unbekannt</c> nach einer gescheiterten Prüfung.</param>
/// <param name="FehlerArt">
/// Nur bei <c>fehler</c> gesetzt: <c>verbindung</c> (abgerissen oder steckengeblieben),
/// <c>pruefung</c> (Größe oder Prüfsumme falsch, Datei gelöscht) oder <c>sonstig</c>
/// (dann sagt <c>meldung</c>, was los ist). Danach wählt das Frontend den Satz
/// im Dialog — nicht nach dem Wortlaut der Meldung.
/// </param>
/// <param name="DownloadUrl">Direkt auf die Setup-Datei, für „Lieber selbst herunterladen" — nur eine <c>https://github.com/…</c>-Adresse, sonst <c>null</c>.</param>
/// <param name="LetzteAktualisierung">Das Ergebnis der letzten Aktualisierung, bis es quittiert ist.</param>
public sealed record AktualisierungsStandDto(
    string LaufendeVersion,
    string? NeueVersion,
    string Zustand,
    long GeladenBytes,
    long? GesamtBytes,
    string? Meldung,
    string? FehlerArt,
    string? DownloadUrl,
    LetzteAktualisierungDto? LetzteAktualisierung)
{
    public static AktualisierungsStandDto From(AktualisierungsStand stand)
    {
        ArgumentNullException.ThrowIfNull(stand);

        return new AktualisierungsStandDto(
            stand.LaufendeVersion,
            stand.NeueVersion,
            ZustandAlsText(stand.Zustand),
            stand.GeladenBytes,
            stand.GesamtBytes,
            stand.Meldung,
            FehlerArtAlsText(stand.FehlerArt),
            stand.DownloadUrl,
            stand.LetzteAktualisierung is { } letzte
                ? new LetzteAktualisierungDto(letzte.ZielVersion, letzte.Erfolgreich)
                : null);
    }

    /// <summary>Ausgeschrieben statt per Enum-Konverter: Der Vertrag soll nicht an einem C#-Bezeichner hängen.</summary>
    public static string ZustandAlsText(AktualisierungsZustand zustand) => zustand switch
    {
        AktualisierungsZustand.Aktuell => "aktuell",
        AktualisierungsZustand.Verfuegbar => "verfuegbar",
        AktualisierungsZustand.Laedt => "laedt",
        AktualisierungsZustand.Bereit => "bereit",
        AktualisierungsZustand.Fehler => "fehler",
        _ => "unbekannt",
    };

    /// <summary>Ebenso ausgeschrieben; <c>null</c>, solange kein Fehler vorliegt.</summary>
    public static string? FehlerArtAlsText(AktualisierungsFehlerArt? art) => art switch
    {
        AktualisierungsFehlerArt.Verbindung => "verbindung",
        AktualisierungsFehlerArt.Pruefung => "pruefung",
        AktualisierungsFehlerArt.Sonstig => "sonstig",
        _ => null,
    };
}

/// <summary>Ergebnis der letzten Aktualisierung, aus der Merkdatei beim Start des Dienstes.</summary>
/// <param name="ZielVersion">Worauf aktualisiert werden sollte.</param>
/// <param name="Erfolgreich">Ob die laufende Version mindestens <see cref="ZielVersion"/> ist.</param>
public sealed record LetzteAktualisierungDto(string ZielVersion, bool Erfolgreich);
