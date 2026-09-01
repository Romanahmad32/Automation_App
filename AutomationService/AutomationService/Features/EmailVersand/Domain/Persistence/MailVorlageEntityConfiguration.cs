using AutomationService.Features.EmailVersand.Domain.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AutomationService.Features.EmailVersand.Domain.Persistence;

/// <summary>
/// Schema-Mapping der Mail-Textvorlagen samt Ausgangsbestand (§4.7). Der Name
/// ist der fachliche Schlüssel (Unique-Index, ohne Rücksicht auf Groß- und
/// Kleinschreibung) — zwei Vorlagen gleichen Namens wären in der Auswahlliste
/// nicht auseinanderzuhalten.
///
/// Der Seed läuft als <c>HasData</c> über die Migration, mit fester Id: Die
/// Kanzlei-Vorlage ist damit von Anfang an da und bleibt beim Ändern dieselbe
/// Zeile, statt bei jedem Start eine weitere anzulegen. Wer sie löscht, ist
/// sie los — sie kommt nicht wieder.
/// </summary>
public class MailVorlageEntityConfiguration : IEntityTypeConfiguration<MailVorlageEntity>
{
    public void Configure(EntityTypeBuilder<MailVorlageEntity> builder)
    {
        builder.Property(v => v.Name).IsRequired().HasMaxLength(128);
        builder.Property(v => v.Betreff).HasMaxLength(512);
        builder.HasIndex(v => v.Name).IsUnique();

        builder.HasData(new MailVorlageEntity
        {
            Id = MailVorlagenVorgabe.MandantenanschreibenId,
            Name = MailVorlagenVorgabe.MandantenanschreibenName,
            Betreff = MailVorlagenVorgabe.MandantenanschreibenBetreff,
            Text = MailVorlagenVorgabe.Mandantenanschreiben,
        });
    }
}
