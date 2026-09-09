namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Der Nummernstand eines Jahrgangs (§6.3): was im Jahrgang schon belegt ist
/// und welche Nummer als nächste vorgeschlagen wird.
/// </summary>
/// <param name="Jahr">Vierstellig ("2026") — derselbe Jahrgang wie in <see cref="RegisterZeile.Jahr"/>.</param>
/// <param name="HoechsteNummer">
/// Die höchste im Jahrgang belegte laufende Nummer, <c>0</c> bei einem leeren
/// Jahrgang — es gibt keine Nummer <c>0</c>, die Null steht hier für „keine".
/// </param>
/// <param name="NaechsteNummer">
/// Der Vorschlag: <see cref="HoechsteNummer"/> + 1. Ausdrücklich nicht die
/// kleinste freie Nummer — eine Lücke im Bestand bleibt Lücke (§6.3).
/// </param>
/// <param name="Belegte">
/// Alle im Jahrgang vergebenen Nummern, aufsteigend und ohne Doppelte — der
/// Bestand kennt echte Doubletten (§6.2), die Liste führt jede trotzdem nur
/// einmal.
/// </param>
public sealed record RegisterNummernStand(
    string Jahr,
    int HoechsteNummer,
    int NaechsteNummer,
    IReadOnlyList<int> Belegte);
