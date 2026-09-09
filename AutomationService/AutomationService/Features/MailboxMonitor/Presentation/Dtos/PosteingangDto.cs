using AutomationService.Features.MailboxMonitor.Domain.Services;

namespace AutomationService.Features.MailboxMonitor.Presentation.Dtos;

public sealed record PosteingangEintragDto(string Id, string Betreff, string Absender, DateTimeOffset? Datum, bool Gelesen, uint Groesse)
{
    public static PosteingangEintragDto From(PosteingangEintrag mail) =>
        new(mail.Id, mail.Betreff, mail.Absender, mail.Datum, mail.Gelesen, mail.Groesse);
}

public sealed record PosteingangSeiteDto(IReadOnlyList<PosteingangEintragDto> Nachrichten, string? NaechsteSeite, int Gesamt)
{
    public static PosteingangSeiteDto From(PosteingangSeite seite) =>
        new(seite.Nachrichten.Select(PosteingangEintragDto.From).ToList(), seite.NaechsteSeite, seite.Gesamt);
}

public sealed record PosteingangInhaltDto(string Text, bool Gekuerzt, IReadOnlyList<string> Anhaenge)
{
    public static PosteingangInhaltDto From(PosteingangInhalt inhalt) => new(inhalt.Text, inhalt.Gekuerzt, inhalt.Anhaenge);
}
