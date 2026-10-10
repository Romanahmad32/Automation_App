using AutomationService.Features.MailboxMonitor.Domain.Services;

namespace AutomationService.Features.MailboxMonitor.Presentation.Dtos;

/// <summary>
/// Eine Zeile im Posteingang. <c>Absender</c> bleibt die ungeteilte Fassung und
/// damit der Rückfall; <c>AbsenderName</c>/<c>AbsenderAdresse</c> sind das, was
/// die Liste zeigt. <c>MessageId</c> ist die Brücke zur erfassten
/// Zentralruf-Antwort: die Message-Id, bei fehlendem Header ersatzweise
/// <c>uidValidity:uid</c> — identisch mit <c>ReceivedReplyDto.mailSchluessel</c>.
/// </summary>
public sealed record PosteingangEintragDto(
    string Id,
    string Betreff,
    string Absender,
    string? AbsenderName,
    string? AbsenderAdresse,
    IReadOnlyList<string> An,
    IReadOnlyList<string> Cc,
    string? MessageId,
    DateTimeOffset? Datum,
    bool Gelesen,
    uint Groesse,
    bool HatAnhaenge,
    int AnzahlAnhaenge)
{
    public static PosteingangEintragDto From(PosteingangEintrag mail) => new(
        mail.Id,
        mail.Betreff,
        mail.Absender,
        mail.AbsenderName,
        mail.AbsenderAdresse,
        mail.An,
        mail.Cc,
        mail.MessageId,
        mail.Datum,
        mail.Gelesen,
        mail.Groesse,
        mail.HatAnhaenge,
        mail.AnzahlAnhaenge);
}

public sealed record PosteingangSeiteDto(IReadOnlyList<PosteingangEintragDto> Nachrichten, string? NaechsteSeite, int Gesamt)
{
    public static PosteingangSeiteDto From(PosteingangSeite seite) =>
        new(seite.Nachrichten.Select(PosteingangEintragDto.From).ToList(), seite.NaechsteSeite, seite.Gesamt);
}

/// <summary>
/// Der geöffnete Inhalt. <c>Html</c> ist bereits entschärft — ohne Skripte und
/// ohne Verweis, der beim Anzeigen etwas nachlädt; <c>Text</c> steht daneben
/// und ist die Fassung für Suche, Kopieren und schmale Fenster.
///
/// <c>MessageId</c> ist die Message-Id, bei fehlendem Header ersatzweise
/// <c>uidValidity:uid</c> — identisch mit <c>ReceivedReplyDto.mailSchluessel</c>.
/// <c>BilderBlockiert</c> ist true, wenn der Filter dafür mindestens eine
/// nachladende Quelle oder ein <c>&lt;base&gt;</c> entfernen musste; die
/// Marke <c>data-blockiert</c> im Html bleibt daneben bestehen.
/// </summary>
public sealed record PosteingangInhaltDto(
    string Text,
    bool Gekuerzt,
    string? Html,
    bool HtmlGekuerzt,
    bool BilderBlockiert,
    string? AbsenderName,
    string? AbsenderAdresse,
    IReadOnlyList<string> An,
    IReadOnlyList<string> Cc,
    DateTimeOffset? Datum,
    string? MessageId,
    IReadOnlyList<PosteingangAnhangDto> Anhaenge)
{
    public static PosteingangInhaltDto From(PosteingangInhalt inhalt) => new(
        inhalt.Text,
        inhalt.Gekuerzt,
        inhalt.Html,
        inhalt.HtmlGekuerzt,
        inhalt.BilderBlockiert,
        inhalt.AbsenderName,
        inhalt.AbsenderAdresse,
        inhalt.An,
        inhalt.Cc,
        inhalt.Datum,
        inhalt.MessageId,
        inhalt.Anhaenge.Select(PosteingangAnhangDto.From).ToList());
}
