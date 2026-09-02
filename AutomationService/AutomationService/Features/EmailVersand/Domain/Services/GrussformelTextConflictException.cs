namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Wird geworfen, wenn derselbe Gruß schon im Bestand steht. Der Controller
/// übersetzt das in 409 Conflict — zwei gleiche Chips nebeneinander wären eine
/// Auswahl, in der man raten muss.
/// </summary>
public sealed class GrussformelTextConflictException(string message) : Exception(message);
