using AutomationService.Features.EmailVersand.Domain.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AutomationService.Features.EmailVersand.Domain.Persistence;

/// <summary>
/// Schema-Mapping der Grußformeln samt Ausgangsbestand (§4.7). Der Text ist
/// der fachliche Schlüssel (Unique-Index) — mit der Kollation <c>NOCASE</c>
/// an der Spalte, denn zwei Grüße, die sich nur in der Großschreibung
/// unterscheiden, sind in der Auswahl beim Verfassen nicht auseinanderzuhalten
/// (ergänzt am 03.09.2026, zusammen mit derselben Lücke bei den Vorlagen).
///
/// Der Seed sind genau die beiden Grüße, die in der übernommenen Kanzlei-Mail
/// vom 25.08.2026 tatsächlich stehen — beobachtete Praxis, nicht eine
/// abgeleitete Aufzählung von Religionen. Alles Weitere legt der Anwalt selbst
/// an (§7.1).
/// </summary>
public class GrussformelEntityConfiguration : IEntityTypeConfiguration<GrussformelEntity>
{
    public void Configure(EntityTypeBuilder<GrussformelEntity> builder)
    {
        builder.Property(g => g.Text).IsRequired().HasMaxLength(128).UseCollation("NOCASE");
        builder.HasIndex(g => g.Text).IsUnique();

        var seed = GrussformelnVorgabe.Ausgangsbestand
            .Select((text, i) => new GrussformelEntity
            {
                Id = i + 1,
                Text = text,
                Sortierung = (i + 1) * 10,
            })
            .ToArray();

        builder.HasData(seed);
    }
}
