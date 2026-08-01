using System.Text.Json.Serialization;

namespace AutomationService.Features.DevSimulation.Domain.Services;

/// <summary>
/// Welche der generischen Zentralruf-Antworten die Simulation erzeugen soll.
/// Als String serialisiert (z. B. "zwischennachricht"), damit das Frontend
/// keine Zahlenwerte kennen muss.
/// </summary>
[JsonConverter(typeof(JsonStringEnumConverter))]
public enum SimulationAntwortTyp
{
    /// <summary>Standardfall: Versicherer wurde ermittelt (Positivantwort mit Datenblock).</summary>
    Versicherer,

    /// <summary>Negativ-Antwort: kein Versicherer zum Kennzeichen/Unfalldatum ermittelt.</summary>
    KeinVersicherer,

    /// <summary>Zwischennachricht: Auskunft nicht sofort möglich, Fachabteilung prüft, Folgemail kommt.</summary>
    Zwischennachricht,
}
