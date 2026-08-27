namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Eine im Mailprogramm eingerichtete Signatur, zur Übernahme in die
/// Einstellungen (§4.7). Der Name ist der, unter dem sie in Outlook steht —
/// eine Kanzlei hat oft mehrere („Kurz", „Vollständig"), und welche gemeint
/// ist, kann nur der Anwalt sagen.
/// </summary>
/// <param name="Name">Anzeigename in Outlook.</param>
/// <param name="Text">Outlooks eigene Nur-Text-Fassung, für die Vorschau.</param>
/// <param name="HatFormat">
/// True, wenn daneben eine formatierte Fassung liegt (Schrift, Farben, Logo).
/// Wie schwer deren Bilder wiegen, sagt erst die Übernahme: Dafür müssten sie
/// hier alle gelesen werden, nur um eine Liste anzuzeigen.
/// </param>
public sealed record OutlookSignatur(string Name, string Text, bool HatFormat = false);
