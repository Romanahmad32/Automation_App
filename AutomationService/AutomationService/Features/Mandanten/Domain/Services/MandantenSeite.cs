using AutomationService.Features.Mandanten.Domain.Persistence;

namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// Ein Ausschnitt des Mandantenregisters samt der beiden Zahlen, die ihn
/// einordnen: wie viele Mandanten es überhaupt gibt und wie viele die Suche
/// trifft.
///
/// Beide gehören in dieselbe Antwort wie der Ausschnitt. Die Oberfläche
/// schreibt „N von M" darüber und muss wissen, wann sie weiterblättern kann —
/// ohne <see cref="Gefiltert"/> bliebe ihr nur die Vermutung „eine volle Seite
/// heißt, es kommt noch was", und die ist bei genau 50 Treffern falsch.
/// </summary>
public sealed record MandantenSeite(
    IReadOnlyList<MandantEntity> Mandanten,
    int Gesamt,
    int Gefiltert);
