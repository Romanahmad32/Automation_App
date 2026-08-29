namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Was beim Öffnen des Entwurfs herauskam (§4.7). Gesendet wurde dabei nichts —
/// das tut der Anwalt im Mailprogramm, und die App erfährt davon nichts mehr.
/// </summary>
/// <param name="Weg">In welchem Programm der Entwurf steht.</param>
/// <param name="Hinweis">
/// Klartext, wenn nicht der Regelweg genommen wurde — etwa weil Outlook fehlt
/// und die Nachricht deshalb als Datei geöffnet wurde. Null im Regelfall.
/// </param>
public sealed record EntwurfErgebnis(EntwurfWeg Weg, string? Hinweis);
