namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Wo der Entwurf gelandet ist (§4.7). Die Unterscheidung zählt für den Anwalt:
/// Ob seine Signatur schon darunter steht, hängt genau daran.
/// </summary>
public enum EntwurfWeg
{
    /// <summary>Als Entwurfsfenster in Outlook — mit dessen eigener Signatur.</summary>
    Outlook,

    /// <summary>Als Datei, geöffnet vom eingerichteten Mailprogramm. Ohne Signatur.</summary>
    Datei,
}
