namespace AutomationService.Features.FormTemplates.Domain.Services;

/// <summary>
/// Wird geworfen, wenn bereits eine Vorlage mit demselben Namen existiert. Der
/// Controller übersetzt das in 409 Conflict, das Frontend in eine
/// FormTemplateException — gleiche Fachregel wie im früheren lokalen Speicher.
/// </summary>
public sealed class FormTemplateNameConflictException(string message) : Exception(message);
