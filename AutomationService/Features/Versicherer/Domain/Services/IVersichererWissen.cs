using AutomationService.Features.Versicherer.Domain.Persistence;
using AutomationService.Features.ZentralrufAutomation.Domain.Services;

namespace AutomationService.Features.Versicherer.Domain.Services;

/// <summary>
/// Wissensbasis der aus Zentralruf-Antworten gelernten Versicherer. Lernt bei
/// jeder geparsten Antwort mit (beide Eingangswege: Postfach-Monitor und
/// manuelles Einfügen) und stellt die bekannte Liste der Oberfläche bereit —
/// zum Füllen fehlender Felder und zur manuellen Auswahl bei Negativ-Antworten.
/// </summary>
public interface IVersichererWissen
{
    /// <summary>
    /// Übernimmt die Versichererdaten einer Antwort ins Register (Upsert über
    /// den normalisierten Namen). Nicht-leere Antwortwerte gewinnen (neuere
    /// Antwort aktualisiert), leere Antwortfelder überschreiben nie vorhandene
    /// Werte. No-op ohne Versicherername (z. B. Negativ-Antwort).
    /// </summary>
    Task MerkeAusAntwortAsync(ZentralrufReplyData data, CancellationToken cancellationToken = default);

    /// <summary>Alle bekannten Versicherer, nach Name sortiert.</summary>
    Task<IReadOnlyList<VersichererEntity>> GetAllAsync(CancellationToken cancellationToken = default);
}
