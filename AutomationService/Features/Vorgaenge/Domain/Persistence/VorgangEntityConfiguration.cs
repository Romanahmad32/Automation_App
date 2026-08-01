using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AutomationService.Features.Vorgaenge.Domain.Persistence;

/// <summary>
/// Schema-Mapping des Vorgangs (vom zentralen DbContext per
/// <c>ApplyConfigurationsFromAssembly</c> automatisch eingesammelt). Liegt
/// bewusst beim Feature, nicht im Context.
/// </summary>
public class VorgangEntityConfiguration : IEntityTypeConfiguration<VorgangEntity>
{
    public void Configure(EntityTypeBuilder<VorgangEntity> builder)
    {
        // Die Referenz ist der fachliche Schlüssel (Zuordnung eingehender
        // Antworten). Bereits normalisiert gespeichert → Unique-Index.
        builder.Property(v => v.Referenz).IsRequired();
        builder.HasIndex(v => v.Referenz).IsUnique();

        // Häufige Filter/Sortierungen: Status (offen/abgeschlossen),
        // Jahr (Register/Archiv) und Mandant (Akte).
        builder.HasIndex(v => v.Status);
        builder.HasIndex(v => v.Jahr);
        builder.HasIndex(v => v.MandantId);
    }
}
