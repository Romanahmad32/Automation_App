namespace AutomationService.Features.WordAutomation.Domain.Services;

/// <summary>Eine Word-Vorlage im Vorlagenordner des Anwenders.</summary>
/// <param name="Name">Dateiname mit Endung, z. B. <c>Vorfahrtverletzung.docx</c>.</param>
/// <param name="Pfad">Vollstaendiger Pfad — den braucht die Dokumenterzeugung.</param>
/// <param name="GeaendertAm">Letzte Aenderung; macht in der Auswahl sichtbar, welche Fassung aktuell ist.</param>
public sealed record VorlagenDatei(string Name, string Pfad, DateTime GeaendertAm);
