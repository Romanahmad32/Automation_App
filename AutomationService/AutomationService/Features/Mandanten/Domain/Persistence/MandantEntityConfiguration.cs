using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AutomationService.Features.Mandanten.Domain.Persistence;

/// <summary>
/// Schema-Mapping des Mandanten. Die Listen liegen als JSON-Spalten mit
/// Default "[]", damit neue Zeilen ohne Sonderbehandlung gültiges JSON tragen.
/// </summary>
public class MandantEntityConfiguration : IEntityTypeConfiguration<MandantEntity>
{
    public void Configure(EntityTypeBuilder<MandantEntity> builder)
    {
        builder.Property(m => m.AktenOrdnernamenJson).HasDefaultValue("[]");
        builder.Property(m => m.KennzeichenJson).HasDefaultValue("[]");
        // Ohne Default trügen die Zeilen aus der Zeit vor dieser Spalte NULL, und
        // jeder Leser müsste den Fall kennen. Eine Grußformel gibt es entweder
        // oder nicht — "nicht" ist die leere Zeichenkette.
        builder.Property(m => m.PersoenlicheGrussformel).HasDefaultValue(string.Empty);
    }
}
