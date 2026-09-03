using AutomationService.Features.EmailVersand.Domain.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AutomationService.Features.EmailVersand.Domain.Persistence;

/// <summary>
/// Schema-Mapping der Anredeanfänge samt Ausgangsbestand (§4.7).
///
/// Der fachliche Schlüssel sind alle <b>drei</b> Formen zusammen (Unique-Index)
/// und nicht die männliche allein: „Guten Tag" lautet in allen drei Formen
/// gleich, und ein zweiter Baustein mit demselben männlichen Anfang aber
/// anderer weiblicher Form ist ein anderer Baustein. Gleich in allen drei
/// Formen heißt dagegen: derselbe — in der Auswahl nicht auseinanderzuhalten.
///
/// Alle drei tragen die Kollation <c>NOCASE</c> (ergänzt am 03.09.2026):
/// „Sehr geehrter" und „sehr geehrter" sind auf dem Schirm derselbe Chip, und
/// ein Unique-Index, der sie unterscheidet, hält nicht, was er verspricht.
/// </summary>
public class AnredeBausteinEntityConfiguration : IEntityTypeConfiguration<AnredeBausteinEntity>
{
    public void Configure(EntityTypeBuilder<AnredeBausteinEntity> builder)
    {
        builder.Property(a => a.Maennlich).IsRequired().HasMaxLength(64).UseCollation("NOCASE");
        builder.Property(a => a.Weiblich).IsRequired().HasMaxLength(64).UseCollation("NOCASE");
        builder.Property(a => a.Neutral).IsRequired().HasMaxLength(64).UseCollation("NOCASE");
        builder.HasIndex(a => new { a.Maennlich, a.Weiblich, a.Neutral }).IsUnique();

        var seed = AnredeBausteineVorgabe.Ausgangsbestand
            .Select((form, i) => new AnredeBausteinEntity
            {
                Id = i + AnredeBausteineVorgabe.SehrGeehrtId,
                Maennlich = form.Maennlich,
                Weiblich = form.Weiblich,
                Neutral = form.Neutral,
                Sortierung = (i + 1) * 10,
            })
            .ToArray();

        builder.HasData(seed);
    }
}
