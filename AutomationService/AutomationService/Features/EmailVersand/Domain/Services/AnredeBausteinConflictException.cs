namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Wird geworfen, wenn es denselben Anredeanfang in allen drei Formen schon
/// gibt. Der Controller übersetzt das in 409 Conflict — zwei gleiche Chips
/// nebeneinander wären eine Auswahl, in der man raten muss.
/// </summary>
public sealed class AnredeBausteinConflictException(string message) : Exception(message);
