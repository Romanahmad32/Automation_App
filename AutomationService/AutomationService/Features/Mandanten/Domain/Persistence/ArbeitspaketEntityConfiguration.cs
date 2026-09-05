using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AutomationService.Features.Mandanten.Domain.Persistence;

/// <summary>
/// Schema-Mapping der Arbeitspakete. Die Paketnummer ist der fachliche
/// Schlüssel und trägt deshalb einen Unique-Index: zwei Zeilen mit derselben
/// Nummer wären genau die Verwechslung, die das Buch verhindern soll — der
/// Anwalt fragt nach „Paket 3" und bekäme zwei Antworten.
/// </summary>
public class ArbeitspaketEntityConfiguration : IEntityTypeConfiguration<ArbeitspaketEntity>
{
    public void Configure(EntityTypeBuilder<ArbeitspaketEntity> builder)
    {
        builder.Property(paket => paket.OrdnernamenJson).IsRequired();
        builder.HasIndex(paket => paket.Nummer).IsUnique();
    }
}
