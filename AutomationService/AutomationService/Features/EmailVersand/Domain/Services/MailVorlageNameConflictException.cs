namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Wird geworfen, wenn schon eine Mail-Textvorlage desselben Namens existiert.
/// Der Controller übersetzt das in 409 Conflict. Der Name ist das, woran der
/// Anwalt die Vorlage beim Verfassen erkennt — zweimal derselbe wäre eine
/// Auswahl, in der man raten muss.
/// </summary>
public sealed class MailVorlageNameConflictException(string message) : Exception(message);
