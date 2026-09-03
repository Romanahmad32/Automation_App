using AutomationService.Features.EmailVersand.Domain.Persistence;

namespace AutomationService.Features.EmailVersand.Presentation.Dtos;

/// <summary>
/// Eingabe zum Anlegen einer Mail-Textvorlage; die Id vergibt der Bestand beim
/// Speichern.
/// </summary>
public sealed record SpeichereMailVorlageDto(string Name, string Betreff, string Text)
{
    public MailVorlageEntity ToEntity() =>
        new() { Name = Name, Betreff = Betreff, Text = Text };
}
