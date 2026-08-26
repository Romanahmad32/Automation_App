namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Ein Versand, der nicht stattgefunden hat — mit einem Grund, der dem Anwalt
/// vorgelesen werden kann. Bewusst eine Ausnahme und kein Rückgabewert: Die
/// Fachlogik kennt nur "gesendet" oder "nicht gesendet", ein halber Versand
/// existiert nicht.
/// </summary>
public sealed class EmailVersandException(EmailVersandFehler grund, string meldung)
    : Exception(meldung)
{
    public EmailVersandFehler Grund { get; } = grund;
}
