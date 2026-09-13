namespace AutomationService.Features.Mandanten.Presentation.Dtos;

/// <summary>
/// Ein einzelner Akten-Ordner, der einem Mandanten gegeben oder genommen wird.
/// Im Rumpf und nicht im Pfad: Ordnernamen tragen Leerzeichen, Umlaute und
/// „&amp;", und ein Pfadsegment müsste jedes davon maskieren.
/// </summary>
public sealed record AktenOrdnerDto(string Ordnername);
