namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Eine im Mailprogramm eingerichtete Signatur, zur Übernahme in die
/// Einstellungen (§4.7). Der Name ist der, unter dem sie in Outlook steht —
/// eine Kanzlei hat oft mehrere („Kurz", „Vollständig"), und welche gemeint
/// ist, kann nur der Anwalt sagen.
/// </summary>
public sealed record OutlookSignatur(string Name, string Text);
