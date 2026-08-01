namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// Wird geworfen, wenn ein anderer Mandant bereits denselben (normalisierten)
/// Namen trägt. Der Controller übersetzt das in 409 Conflict, das Frontend in
/// eine MandantException mit dieser Meldung — gleiche Fachregel wie bisher im
/// lokalen Register.
/// </summary>
public sealed class MandantNameConflictException(string message) : Exception(message);
