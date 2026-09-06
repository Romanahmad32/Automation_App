using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AutomationService.Features.Mandanten.Domain.Persistence;

/// <summary>
/// Schema-Mapping der Arbeitspakete. Die Paketnummer trägt einen
/// Unique-Index: Sie ist die Zahl, mit der der Anwalt arbeitet
/// („Paket 3 ist noch offen"), und zwei Zeilen mit derselben Nummer machten
/// jede Aussage darüber mehrdeutig. Der Index ist zugleich der Wächter über
/// die Vergabe (Maximum + 1) — schriebe sie einmal zwei Pakete mit derselben
/// Nummer, fiele das hier auf und nicht erst dem Anwalt.
///
/// Die Ordnerliste liegt wie beim Mandanten als JSON-Spalte mit Default "[]":
/// Sie wird immer als Ganzes gelesen und nie einzeln abgefragt, und eine neue
/// Zeile trägt so ohne Sonderbehandlung gültiges JSON.
/// </summary>
public class ImportPaketEntityConfiguration : IEntityTypeConfiguration<ImportPaketEntity>
{
    public void Configure(EntityTypeBuilder<ImportPaketEntity> builder)
    {
        builder.Property(p => p.OrdnernamenJson).IsRequired().HasDefaultValue("[]");
        builder.HasIndex(p => p.Nummer).IsUnique();
    }
}
