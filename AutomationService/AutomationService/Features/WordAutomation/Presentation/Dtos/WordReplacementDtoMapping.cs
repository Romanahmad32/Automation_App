using AutomationService.Features.WordAutomation.Domain.Services;

namespace AutomationService.Features.WordAutomation.Presentation.Dtos;

/// <summary>
/// Bildet das HTTP-DTO auf den Domänen-Auftrag ab. Diese Richtung ist die
/// einzige erlaubte: die Presentation kennt die Domain, nicht umgekehrt. Ein
/// neues Feld im DTO bleibt damit ohne Wirkung, bis es hier bewusst
/// durchgereicht wird.
/// </summary>
public static class WordReplacementDtoMapping
{
    public static WordReplacementRequest ToDomain(this WordReplacementDto dto)
    {
        ArgumentNullException.ThrowIfNull(dto);

        return new WordReplacementRequest
        {
            TemplateFilePath = dto.TemplateFilePath,
            // Kopie mit ausdrücklichem Vergleich: der Erzeuger schlägt Platzhalter
            // ohne Rücksicht auf Groß-/Kleinschreibung nach, und das darf nicht
            // davon abhängen, welchen Comparer das Model-Binding mitgibt.
            ReplacePatterns = new Dictionary<string, string>(
                dto.ReplacePatterns ?? [],
                StringComparer.OrdinalIgnoreCase),
            OutputFileName = dto.OutputFileName,
            OutputDirectory = dto.OutputDirectory,
            DamageListing = dto.DamageListing?.ToDomain(),
            Vorsteuerabzugsberechtigt = dto.Vorsteuerabzugsberechtigt,
        };
    }

    public static DamageListing ToDomain(this DamageListingDto dto)
    {
        ArgumentNullException.ThrowIfNull(dto);

        return new DamageListing
        {
            Items = dto.Items.Select(item => item.ToDomain()).ToList(),
            Gebuehrensatz = dto.Gebuehrensatz,
            ApplyVat = dto.ApplyVat,
            GeschaeftsgebuehrOverride = dto.GeschaeftsgebuehrOverride,
            AuslagenpauschaleOverride = dto.AuslagenpauschaleOverride,
            HeaderColorHex = dto.HeaderColorHex,
        };
    }

    public static DamageItem ToDomain(this DamageItemDto dto)
    {
        ArgumentNullException.ThrowIfNull(dto);

        return new DamageItem { Description = dto.Description, Amount = dto.Amount };
    }
}
