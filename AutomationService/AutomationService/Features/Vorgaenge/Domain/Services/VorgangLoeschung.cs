using System.Globalization;
using AutomationService.Features.RegisterHistorie.Domain.Services;
using AutomationService.Features.Vorgaenge.Domain.Persistence;

namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Löscht einen Vorgang und regelt dabei die Kopplung zu seiner gespiegelten
/// Registerzeile (§6.3): Bleibt sie erhalten, wird sie <b>vor</b> dem Löschen
/// des Vorgangs zu einer eigenständigen Zeile der übernommenen Historie —
/// danach gäbe es den Vorgang nicht mehr, aus dem sie sich hätte bauen lassen.
///
/// Baut die Zeile über <see cref="RegisterZeilenBau.Zeile"/> — dieselbe
/// Ableitung, die auch die Registeransicht und der Word/PDF-Spiegel benutzen.
/// Eine zweite Herleitung von Jahrgang, Zeichen und Parteien wäre genau die
/// Duplizierung, die jene Klasse verhindern soll.
///
/// Erreicht die Registerhistorie ausschließlich über
/// <see cref="IRegisterHistorie"/>, nie über ihre Tabelle: Die Kante zwischen
/// den Slices verläuft nur in diese Richtung.
/// </summary>
public sealed class VorgangLoeschung(IVorgangRepository vorgaenge, IRegisterHistorie historie)
{
    /// <summary>
    /// Löscht den Vorgang zur Referenz. <c>false</c>, wenn keiner passte — dann
    /// bleibt auch die Registerhistorie unberührt.
    ///
    /// <paramref name="registerzeileBehalten"/> entspricht der Rückfrage im
    /// Frontend (§6.3 „Vorgang löschen fragt nach der Registerzeile"):
    /// <c>true</c> übernimmt die gespiegelte Zeile vorher in die Historie,
    /// <c>false</c> lässt sie mit dem Vorgang verschwinden.
    ///
    /// Eine Kollision des natürlichen Schlüssels bricht das Löschen nicht ab:
    /// Steht die Zeile schon im Register, gibt es ohnehin nichts zu bewahren
    /// (siehe <see cref="IRegisterHistorie.UebernehmeAsync"/>), und der Vorgang
    /// soll trotzdem verschwinden.
    /// </summary>
    public async Task<bool> LoescheAsync(
        string referenz,
        bool registerzeileBehalten,
        CancellationToken cancellationToken = default)
    {
        var vorgang = await vorgaenge.GetByReferenzAsync(referenz, cancellationToken);
        if (vorgang is null) return false;

        if (registerzeileBehalten) await UebernehmeRegisterzeileAsync(vorgang, cancellationToken);

        return await vorgaenge.DeleteAsync(referenz, cancellationToken);
    }

    /// <summary>
    /// Ohne laufende Nummer gibt es keine gespiegelte Zeile, die sich sinnvoll
    /// übernehmen ließe — der Vorgang stand noch an keiner festen Stelle des
    /// Jahrgangs. Dann bleibt nichts zu tun, statt eine Zeile mit der
    /// Platzhalternummer 0 anzulegen, die im Jahrgang nichts bedeutet.
    /// </summary>
    async Task UebernehmeRegisterzeileAsync(VorgangEntity vorgang, CancellationToken cancellationToken)
    {
        var zeile = RegisterZeilenBau.Zeile(vorgang);
        if (zeile.LaufendeNummer is null) return;
        if (!int.TryParse(zeile.Jahr, NumberStyles.Integer, CultureInfo.InvariantCulture, out var jahr)) return;

        await historie.UebernehmeAsync(
            new RegisterHistorieUebernahme(
                jahr,
                zeile.LaufendeNummer.Value,
                NummerZusatz: string.Empty,
                Spalte1: zeile.LaufendeNummer.Value.ToString(CultureInfo.InvariantCulture),
                Abteilung: vorgang.Abteilung ?? string.Empty,
                Parteien: zeile.Parteien,
                Sachbestand: zeile.Sachbestand,
                Rechtsgebiet: zeile.Rechtsgebiet),
            cancellationToken);
    }
}
