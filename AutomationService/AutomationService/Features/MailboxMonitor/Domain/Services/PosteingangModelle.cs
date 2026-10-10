namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// Eine Zeile im Posteingang. <see cref="Absender"/> bleibt die ungeteilte
/// Fassung (<c>"Max Muster" &lt;max@x.de&gt;</c>) — sie ist der Rückfall, wenn
/// der Umschlag keine auswertbare Adresse trägt; Name und Adresse daneben sind
/// das, was die Liste tatsächlich anzeigt.
///
/// <see cref="MessageId"/> ist die Brücke zur erfassten Zentralruf-Antwort:
/// ihre Message-Id, hilfsweise <c>UIDVALIDITY:UID</c> (<see
/// cref="PosteingangKopf.MailSchluessel"/>) — derselbe Schlüssel, den der
/// Monitor als Dedupe-Schlüssel und als <c>MailSchluessel</c> der erfassten
/// Antwort ablegt. Nur weil beide Seiten denselben Rückfall bilden, erkennt
/// die Oberfläche eine Posteingangszeile ohne Message-Id-Header als bereits
/// erfasst wieder.
/// </summary>
public sealed record PosteingangEintrag(
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
    int AnzahlAnhaenge);

public sealed record PosteingangSeite(
    IReadOnlyList<PosteingangEintrag> Nachrichten, string? NaechsteSeite, int Gesamt);

/// <summary>
/// Ein Anhang, wie ihn die BODYSTRUCTURE beschreibt — <b>ohne</b> ihn geladen
/// zu haben. <see cref="Id"/> ist der IMAP-Teilbezeichner (<c>"2"</c>,
/// <c>"2.1"</c>); mit ihm holt der Anwalt die Datei einzeln ins Zwischenlager.
/// </summary>
public sealed record PosteingangAnhang(string Id, string Dateiname, long Groesse, string Medientyp);

/// <summary>
/// Der geöffnete Inhalt einer Nachricht. Text und HTML stehen nebeneinander und
/// werden <b>getrennt</b> begrenzt: Eine Mail kann eine harmlose Textfassung und
/// eine überlange HTML-Fassung tragen, und dann soll wenigstens der Text
/// vollständig lesbar bleiben.
///
/// <see cref="MessageId"/> ist derselbe Schlüssel, den eine erfasste
/// Zentralruf-Antwort als <c>MailSchluessel</c> trägt (<see
/// cref="PosteingangKopf.MailSchluessel"/>); <see cref="BilderBlockiert"/> ist
/// true, wenn der Filter dafür mindestens eine nachladende Quelle oder ein
/// <c>&lt;base&gt;</c> entfernen musste.
/// </summary>
public sealed record PosteingangInhalt(
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
    IReadOnlyList<PosteingangAnhang> Anhaenge);

/// <summary>
/// Eine ins Zwischenlager geholte Datei — ein Anhang oder die ganze Nachricht
/// als <c>.eml</c>. Zurück geht der <b>Pfad</b>, nicht der Inhalt: Öffnen,
/// Anhängen beim Versand und Ablegen in die Akte arbeiten in dieser App
/// durchweg mit lokalen Pfaden.
/// </summary>
public sealed record PosteingangAnhangAblage(string Dateiname, string Pfad, long Groesse);

public sealed class PosteingangException(string message, int status = 409) : Exception(message)
{
    public int Status { get; } = status;
}

/// <summary>
/// Ergebnis von <see cref="PosteingangHtmlFilter.FuerAnzeigeMitErgebnis"/>:
/// die entschärfte Fassung neben der Frage, ob dabei überhaupt etwas
/// Nachladendes zu entschärfen war. <see cref="BilderBlockiert"/> ist die
/// Grundlage für das gleichnamige DTO-Feld — die Oberfläche muss dafür nicht
/// mehr selbst nach der Marke <c>data-blockiert</c> im Text suchen.
/// </summary>
public sealed record PosteingangHtmlFilterErgebnis(string Html, bool BilderBlockiert);
