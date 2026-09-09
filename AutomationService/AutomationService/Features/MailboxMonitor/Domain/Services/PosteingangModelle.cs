namespace AutomationService.Features.MailboxMonitor.Domain.Services;

public sealed record PosteingangEintrag(
    string Id, string Betreff, string Absender, DateTimeOffset? Datum, bool Gelesen, uint Groesse);

public sealed record PosteingangSeite(
    IReadOnlyList<PosteingangEintrag> Nachrichten, string? NaechsteSeite, int Gesamt);

public sealed record PosteingangInhalt(string Text, bool Gekuerzt, IReadOnlyList<string> Anhaenge);

public sealed class PosteingangException(string message, int status = 409) : Exception(message)
{
    public int Status { get; } = status;
}
