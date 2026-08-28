using AutomationService.Features.EmailVersand.Domain.Services;

namespace AutomationService.Features.EmailVersand.Presentation.Dtos;

/// <summary>
/// Welches Outlook auf diesem Rechner steht (§4.7). Die Oberfläche fragt es,
/// bevor sie Knöpfe anbietet, die es brauchen — und schreibt hin, warum sie
/// nichts liefern, statt es geschehen zu lassen.
/// </summary>
/// <param name="Steuerbar">
/// Ob Entwurf, Anhang-Griff und Signatur-Übernahme überhaupt etwas liefern
/// können. False heißt nicht „kaputt": Der Direktversand läuft über das
/// Postfach und ist davon unberührt.
/// </param>
/// <param name="Neu">
/// Die Store-App „Outlook für Windows" liegt auf dem Rechner. Entscheidet nur
/// die Formulierung des Hinweises, nicht was möglich ist.
/// </param>
/// <param name="Hinweis">Der Grund im Klartext; null, wenn alles da ist.</param>
public sealed record OutlookStandDto(bool Steuerbar, bool Neu, string? Hinweis)
{
    public static OutlookStandDto From(OutlookStand stand) =>
        new(stand.Steuerbar, stand.Neu, stand.Hinweis);
}
