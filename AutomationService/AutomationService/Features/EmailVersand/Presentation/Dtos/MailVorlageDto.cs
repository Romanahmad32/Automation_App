using AutomationService.Features.EmailVersand.Domain.Persistence;

namespace AutomationService.Features.EmailVersand.Presentation.Dtos;

/// <summary>
/// Übertragungsformat einer Mail-Textvorlage (§4.7). PascalCase wird als
/// camelCase serialisiert und passt damit 1:1 zur Flutter-Entität
/// <c>MailVorlage</c>.
/// </summary>
public sealed record MailVorlageDto(int Id, string Name, string Betreff, string Text)
{
    public static MailVorlageDto From(MailVorlageEntity e) =>
        new(e.Id, e.Name, e.Betreff, e.Text);

    public MailVorlageEntity ToEntity() =>
        new() { Id = Id, Name = Name, Betreff = Betreff, Text = Text };
}
