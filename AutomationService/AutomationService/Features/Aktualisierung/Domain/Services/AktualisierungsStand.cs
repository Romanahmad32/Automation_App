namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>Wo die Aktualisierung gerade steht (#196).</summary>
public enum AktualisierungsZustand
{
    /// <summary>Noch nicht geprüft, oder die Prüfung ging nicht (kein Netz, Firewall, GitHub weg oder an seinem Ratenlimit).</summary>
    Unbekannt,

    /// <summary>Geprüft, nichts Neueres.</summary>
    Aktuell,

    /// <summary>Eine neue Version mit prüfbarer Setup-Datei ist da.</summary>
    Verfuegbar,

    /// <summary>Der Download läuft.</summary>
    Laedt,

    /// <summary>Heruntergeladen und geprüft; der Installer kann starten.</summary>
    Bereit,

    /// <summary>Eine neue Version ist da, aber Laden, Prüfen oder Starten ging nicht — siehe Meldung.</summary>
    Fehler,
}

/// <summary>Ergebnis der letzten Aktualisierung, aus der Merkdatei beim Start.</summary>
/// <param name="ZielVersion">Worauf aktualisiert werden sollte, dreistellig.</param>
/// <param name="Erfolgreich">Ob die laufende Version mindestens die Zielversion ist.</param>
public sealed record LetzteAktualisierung(string ZielVersion, bool Erfolgreich);

/// <summary>Eine Momentaufnahme — unveränderlich, also gefahrlos aus dem Lock zu reichen.</summary>
/// <param name="LaufendeVersion">Wie <c>GET /health</c> sie meldet.</param>
/// <param name="NeueVersion">Dreistellig, sobald eine neuere bekannt ist.</param>
/// <param name="Zustand">Siehe <see cref="AktualisierungsZustand"/>.</param>
/// <param name="GeladenBytes">Fortschritt des Downloads.</param>
/// <param name="GesamtBytes">Größe der ladbaren Setup-Datei, sobald bekannt.</param>
/// <param name="Meldung">Deutsch und für den Anwender verständlich — nie ein Stacktrace.</param>
/// <param name="FehlerArt">Genau dann gesetzt, wenn <paramref name="Zustand"/> <see cref="AktualisierungsZustand.Fehler"/> ist.</param>
/// <param name="DownloadUrl">Der Rückfallweg „Lieber selbst herunterladen" (<c>browser_download_url</c>).</param>
/// <param name="LetzteAktualisierung">Aus der Merkdatei, bis das Frontend quittiert.</param>
public sealed record AktualisierungsStand(
    string LaufendeVersion,
    string? NeueVersion,
    AktualisierungsZustand Zustand,
    long GeladenBytes,
    long? GesamtBytes,
    string? Meldung,
    AktualisierungsFehlerArt? FehlerArt,
    string? DownloadUrl,
    LetzteAktualisierung? LetzteAktualisierung);

/// <summary>
/// Antwort eines Schritts, der abgelehnt werden kann: der Stand danach, und
/// bei einer Ablehnung der Grund (dann 409).
/// </summary>
public sealed record AktualisierungsSchritt(AktualisierungsStand Stand, string? Ablehnung);
