using System.Globalization;
using AutomationService.Core.Persistence;
using AutomationService.Features.RegisterHistorie.Domain.Services;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Baut die Zeilen der Registeransicht aus beiden Quellen (§6.2).
///
/// <c>nurAbgeschlossene: false</c> — der Bildschirm zeigt auch die laufenden
/// Vorgänge, so wie die Registeransicht es bisher tat. Die Spiegeldatei behält
/// davon unberührt ihren eigenen Filter aus den Einstellungen: Was am Bildschirm
/// steht, darf davon abhängen, was gerade läuft; was in der Kanzleidatei steht,
/// nicht.
///
/// Der Jahrgangsfilter greift <em>nach</em> dem Bauen und nicht in der Abfrage:
/// Der Jahrgang eines Vorgangs ist eine abgeleitete Größe
/// (<see cref="RegisterZeilenBau.Jahrgang"/>) und steht so in keiner Spalte.
/// </summary>
public sealed class RegisterZeilenDienst(AutomationDbContext db, IRegisterHistorie historie)
    : IRegisterZeilenDienst
{
    public async Task<IReadOnlyList<RegisterZeile>> LadeAsync(
        int? jahrgang,
        CancellationToken cancellationToken = default)
    {
        var vorgaenge = await db.Vorgaenge.AsNoTracking().ToListAsync(cancellationToken);
        var historischeZeilen = await historie.GetAllAsync(jahrgang, cancellationToken);

        var zeilen = RegisterZeilenBau.Aus(vorgaenge, historischeZeilen, nurAbgeschlossene: false);
        if (jahrgang is null) return zeilen;

        var jahr = jahrgang.Value.ToString(CultureInfo.InvariantCulture);
        return [.. zeilen.Where(zeile => string.Equals(zeile.Jahr, jahr, StringComparison.Ordinal))];
    }
}
