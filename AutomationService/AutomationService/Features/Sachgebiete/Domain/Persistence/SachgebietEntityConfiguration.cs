using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AutomationService.Features.Sachgebiete.Domain.Persistence;

/// <summary>
/// Schema-Mapping des Sachgebietskatalogs samt Seed (§7.1). Das Kürzel ist der
/// fachliche Schlüssel (Unique-Index). Der Seed läuft als HasData über die
/// Migration: feste Ids, damit spätere Katalogpflege in der App (§7.1, [S])
/// dieselben Zeilen ändert statt Duplikate anzulegen.
///
/// Vertragsrecht steht bewusst nicht im Seed — es hatte nie ein eigenes
/// Kürzel, und Einträge ohne Kürzel sind nicht erlaubt (§7.1).
/// </summary>
public class SachgebietEntityConfiguration : IEntityTypeConfiguration<SachgebietEntity>
{
    public void Configure(EntityTypeBuilder<SachgebietEntity> builder)
    {
        builder.Property(s => s.Kuerzel).IsRequired().HasMaxLength(16);
        builder.Property(s => s.Name).IsRequired().HasMaxLength(128);
        builder.Property(s => s.RechtsgebietVorschlag).IsRequired().HasMaxLength(128);
        builder.HasIndex(s => s.Kuerzel).IsUnique();

        builder.HasData(
            Eintrag(1, "C01", "Zivilrecht (allgemein)", "Zivilrecht"),
            Eintrag(2, "C01a", "Arbeitsrecht"),
            Eintrag(3, "C02", "Familienrecht"),
            Eintrag(4, "C03", "Verkehrsrecht"),
            Eintrag(5, "C03o", "Ordnungswidrigkeitssache"),
            Eintrag(6, "C04", "Verkehrsstrafrecht"),
            Eintrag(7, "C05", "Strafrecht"),
            Eintrag(8, "C06", "Verwaltungsrecht"),
            Eintrag(9, "C06a", "Ausländer- und Asylrecht"),
            Eintrag(10, "C06s", "Sozialrecht"),
            Eintrag(11, "C07", "Sonstiges"),
            Eintrag(12, "C07m", "Markenrecht"));
    }

    static SachgebietEntity Eintrag(int id, string kuerzel, string name, string? vorschlag = null)
        => new()
        {
            Id = id,
            Kuerzel = kuerzel,
            Name = name,
            RechtsgebietVorschlag = vorschlag ?? name,
            // Zehnerschritte, damit die Pflege später zwischen zwei Einträgen
            // einsortieren kann, ohne den ganzen Katalog umzunummerieren.
            Sortierung = id * 10,
            Aktiv = true,
        };
}
