using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AutomationService.Features.Mandanten.Domain.Persistence;

/// <summary>
/// Schema-Mapping der Ordner-Vermerke. Der Ordnername ist der fachliche
/// Schlüssel — Unique-Index, damit ein Ordner nicht zweimal entschieden wird.
///
/// Der Name trägt die Kollation <c>NOCASE</c>, und das ist keine Feinheit: Er
/// kommt aus dem Windows-Dateisystem, das „VUnfallursache Mark" und
/// „Vunfallursache Mark" nicht unterscheiden kann — zwei solche Ordner gibt es
/// dort nicht. Binär verglichen bekäme derselbe Ordner zwei Vermerkzeilen, und
/// das Zurücknehmen über die abweichende Schreibweise fände seine Zeile nicht:
/// der Ordner wäre zugeordnet und zugleich „ohne Mandantenbezug". Der
/// Unique-Index erbt die Kollation der Spalte und hält damit dieselbe Regel.
/// </summary>
public class OrdnerStatusEntityConfiguration : IEntityTypeConfiguration<OrdnerStatusEntity>
{
    public void Configure(EntityTypeBuilder<OrdnerStatusEntity> builder)
    {
        builder.Property(o => o.Ordnername).IsRequired().UseCollation("NOCASE");
        builder.Property(o => o.Status).IsRequired();
        builder.HasIndex(o => o.Ordnername).IsUnique();
    }
}
