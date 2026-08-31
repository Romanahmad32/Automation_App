using AutomationService.Core.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.FormTemplates.Domain.Services;

/// <summary>
/// Einmalige Umstellung des Bestands, wenn der Anwalt den Vorlagenordner (neu)
/// waehlt (#33): Absolute Pfade, die im gewaehlten Ordner liegen, werden auf
/// den Rest ab dem Ordner verkuerzt. Aussenliegende bleiben absolut — sie
/// weiter zu benutzen ist richtig, nur mitnehmen auf einen zweiten Rechner
/// laesst sich das nicht (das Hineinholen bietet die Oberflaeche an).
/// </summary>
public static class VorlagenPfadUmstellung
{
    /// <summary>Relativiert alle Bestandspfade; liefert die Zahl der geaenderten Vorlagen.</summary>
    public static async Task<int> StelleUmAsync(
        AutomationDbContext db, string ordner, CancellationToken cancellationToken)
    {
        var geaendert = 0;
        var vorlagen = await db.FormTemplates.ToListAsync(cancellationToken);
        foreach (var vorlage in vorlagen)
        {
            var ohne = VorlagenPfad.MacheRelativ(ordner, vorlage.WordFilePathOhneAuflistung);
            var mit = VorlagenPfad.MacheRelativ(ordner, vorlage.WordFilePathMitAuflistung);
            if (ohne == vorlage.WordFilePathOhneAuflistung && mit == vorlage.WordFilePathMitAuflistung)
            {
                continue;
            }

            vorlage.WordFilePathOhneAuflistung = ohne;
            vorlage.WordFilePathMitAuflistung = mit;
            geaendert++;
        }

        if (geaendert > 0)
        {
            await db.SaveChangesAsync(cancellationToken);
        }

        return geaendert;
    }
}
