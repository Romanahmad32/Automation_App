namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// Wird geworfen, wenn ein Arbeitspaket geholt wird, obwohl vom übergebenen
/// Bestand kein Ordner mehr offen ist. Der Controller übersetzt das in 409
/// Conflict.
///
/// Ein leeres Paket zu buchen wäre die bequemere Antwort und die schlechtere:
/// es stünde danach für immer ohne „eingelesen am" in der Historie und ließe
/// den Anwalt eine Lücke suchen, die es nicht gibt. Die Historie gibt es, um
/// echte Lücken sichtbar zu machen — ein Eintrag, der immer wie eine aussieht,
/// macht sie unbrauchbar.
/// </summary>
public sealed class KeineOffenenOrdnerException(string message) : Exception(message);
