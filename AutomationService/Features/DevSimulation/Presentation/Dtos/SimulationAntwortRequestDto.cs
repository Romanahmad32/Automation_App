using AutomationService.Features.DevSimulation.Domain.Services;

namespace AutomationService.Features.DevSimulation.Presentation.Dtos;

/// <summary>
/// Eingabe der Antwort-Simulation. Nur die Referenz ist Pflicht — sie steuert
/// die Zuordnung zum Vorgang; alles Übrige wird mit plausiblen Werten belegt.
/// <see cref="AntwortTyp"/> wählt die Antwortart (Standard: Versicherer ermittelt).
/// </summary>
public sealed record SimulationAntwortRequestDto(
    string Referenz,
    string? Kennzeichen = null,
    string? UnfallDatum = null,
    string? VersichererName = null,
    SimulationAntwortTyp AntwortTyp = SimulationAntwortTyp.Versicherer);
