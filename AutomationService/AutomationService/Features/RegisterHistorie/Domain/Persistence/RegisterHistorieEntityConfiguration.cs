using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AutomationService.Features.RegisterHistorie.Domain.Persistence;

/// <summary>
/// Schema-Mapping der Registerhistorie (§6.2).
///
/// Der Unique-Index über <c>(Jahr, LaufendeNummer, NummerZusatz)</c> ist die
/// eigentliche Zusicherung dieser Tabelle: Er macht das zweimalige Einlesen
/// desselben Jahrgangs harmlos und verhindert, dass zwei Läufe dieselbe
/// Aktennummer doppelt anlegen — auch dann, wenn die Prüfung im Dienst je
/// einmal einen Fehler hätte. Der Zusatz gehört dazu, weil der Bestand ihn
/// führt: <c>10/19</c> und <c>10/19-I</c> sind zwei Akten und müssen
/// nebeneinander bestehen können. Der Index auf <c>Jahr</c> allein trägt die
/// Ansicht: gefiltert wird fast immer nach Jahrgang.
///
/// Gefiltert auf <c>LaufendeNummer &gt; 0</c>: Eine Zeile ohne laufende Nummer
/// steht außerhalb der Nummernfolge und hat keinen natürlichen Schlüssel —
/// mehrere davon im selben Jahrgang sind kein Widerspruch (<c>JahrgangImportLauf</c>
/// führt keine Duplikatprüfung für sie) und dürften ohne den Filter nicht
/// nebeneinander gespeichert werden, weil sie alle denselben Platzhalter
/// <c>(Jahr, 0, "")</c> träfen. Der Filter lässt den Index seine Aufgabe für
/// echte Nummern behalten, ohne nummernlose Zeilen zu verfälschen.
///
/// <c>Kennung</c> ist zusätzlich eindeutig, weil sie die stabile Referenz nach
/// außen ist (§7.2) — zwei Zeilen mit derselben Kennung wären zwei Zeilen ohne.
/// </summary>
public class RegisterHistorieEntityConfiguration : IEntityTypeConfiguration<RegisterHistorieEntity>
{
    public void Configure(EntityTypeBuilder<RegisterHistorieEntity> builder)
    {
        builder.ToTable("RegisterHistorie");

        builder.Property(z => z.Kennung).IsRequired().HasMaxLength(64);
        builder.Property(z => z.NummerZusatz).IsRequired().HasMaxLength(16);
        builder.Property(z => z.Spalte1).IsRequired().HasMaxLength(32);
        builder.Property(z => z.Aktenzeichen).IsRequired().HasMaxLength(64);
        builder.Property(z => z.Abteilung).IsRequired().HasMaxLength(16);
        builder.Property(z => z.AbteilungRoh).IsRequired().HasMaxLength(32);
        builder.Property(z => z.Sachart).IsRequired().HasMaxLength(128);
        builder.Property(z => z.Mandant).IsRequired().HasMaxLength(256);
        builder.Property(z => z.Gegner).IsRequired().HasMaxLength(256);
        builder.Property(z => z.Sachbestand).IsRequired().HasMaxLength(512);
        builder.Property(z => z.Unfalldatum).IsRequired().HasMaxLength(32);
        builder.Property(z => z.Rechtsgebiet).IsRequired().HasMaxLength(128);
        builder.Property(z => z.Freitext).IsRequired();
        builder.Property(z => z.Sicherheit).IsRequired().HasMaxLength(16);
        builder.Property(z => z.HinweiseJson).IsRequired().HasDefaultValue("[]");
        builder.Property(z => z.BefundeJson).IsRequired().HasDefaultValue("[]");
        builder.Property(z => z.Quelle).IsRequired().HasMaxLength(32);

        builder.HasIndex(z => new { z.Jahr, z.LaufendeNummer, z.NummerZusatz })
            .IsUnique()
            .HasFilter("LaufendeNummer > 0");
        builder.HasIndex(z => z.Jahr);
        builder.HasIndex(z => z.Kennung).IsUnique();
    }
}
