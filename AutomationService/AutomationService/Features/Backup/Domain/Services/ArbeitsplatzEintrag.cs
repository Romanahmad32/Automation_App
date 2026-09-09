namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Was ein Arbeitsplatz im gemeinsamen Sicherungsordner über sich hinterlässt
/// (§7.2, #39) — die Grundlage der Frage „Zuletzt heute 14:12 auf BUERO-PC
/// gearbeitet. Diesen Stand übernehmen?".
/// </summary>
/// <param name="Rechnername">
/// Name des Rechners, wie ihn Windows kennt. Steht sowohl im Dateinamen als auch
/// hier: der Dateiname hält die Akten der Arbeitsplätze auseinander, das Feld
/// sagt, wem der Inhalt gehört. Gelesen wird das Feld — ein Dateiname kann eine
/// Konfliktkopie sein, der Inhalt bleibt richtig.
/// </param>
/// <param name="ZuletztGearbeitet">
/// Wann dieser Arbeitsplatz die App zuletzt offen hatte (beim Start und beim
/// Beenden fortgeschrieben). Das ist der Zeitpunkt, den der Anwalt auf dem
/// Bildschirm liest — er beantwortet „wann war ich da zuletzt dran?".
/// </param>
/// <param name="GesichertAm">
/// Wann der Stand zuletzt als Archiv abgelegt wurde, oder <c>null</c>, wenn es
/// noch keines gibt. <em>Daran</em> entscheidet sich das Übernahme-Angebot:
/// Übernehmen lässt sich nur, was auch als Datei dasteht. Die Trennung von
/// <paramref name="ZuletztGearbeitet"/> ist kein Zierrat — ein Arbeitsplatz, der
/// heute nur gestartet und wieder geschlossen wurde, wäre sonst der „neuere"
/// Stand, obwohl sein Archiv von vorgestern ist.
/// </param>
/// <param name="Sicherung">Dateiname des Archivs zu <paramref name="GesichertAm"/>.</param>
/// <param name="Programmfassung">
/// Fassung, die den Eintrag geschrieben hat. Beim Support die erste Frage; bei
/// einer Übernahme die zweite — ein älterer Stand kann eine neuere Sicherung
/// nicht unbedingt lesen.
/// </param>
public sealed record ArbeitsplatzEintrag(
    string Rechnername,
    DateTime ZuletztGearbeitet,
    DateTime? GesichertAm,
    string? Sicherung,
    string Programmfassung)
{
    public string? Revision { get; init; }
    public string[] Vorfahren { get; init; } = [];
    public string? Sha256 { get; init; }
    public long? Bytes { get; init; }

    // Die Herkunftskette ist ein Wert: Nach JSON-Rundreise ist das Array neu,
    // der Arbeitsplatz-Eintrag aber weiterhin derselbe.
    public bool Equals(ArbeitsplatzEintrag? other) => other is not null
        && Rechnername == other.Rechnername && ZuletztGearbeitet == other.ZuletztGearbeitet
        && GesichertAm == other.GesichertAm && Sicherung == other.Sicherung
        && Programmfassung == other.Programmfassung && Revision == other.Revision
        && Sha256 == other.Sha256 && Bytes == other.Bytes
        && Vorfahren.SequenceEqual(other.Vorfahren, StringComparer.Ordinal);

    public override int GetHashCode()
    {
        var hash = new HashCode();
        hash.Add(Rechnername);
        hash.Add(ZuletztGearbeitet);
        hash.Add(GesichertAm);
        hash.Add(Sicherung);
        hash.Add(Programmfassung);
        hash.Add(Revision);
        hash.Add(Sha256);
        hash.Add(Bytes);
        foreach (var vorfahr in Vorfahren) hash.Add(vorfahr);
        return hash.ToHashCode();
    }
}
