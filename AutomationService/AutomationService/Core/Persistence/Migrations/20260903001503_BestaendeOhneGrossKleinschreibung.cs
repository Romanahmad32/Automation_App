using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AutomationService.Core.Persistence.Migrations
{
    /// <summary>
    /// Legt die Kollation <c>NOCASE</c> auf die fachlichen Schlüssel der drei
    /// Mail-Bestände: Vorlagenname, Grußtext und die drei Formen eines
    /// Anredeanfangs.
    ///
    /// Deren Unique-Indizes gab es von Anfang an, und die Klassenkommentare
    /// versprachen auch von Anfang an, sie hielten „ohne Rücksicht auf Groß-
    /// und Kleinschreibung" — nur war die Kollation BINARY. „anschreiben"
    /// neben „Anschreiben" ging deshalb durch, und in der Auswahlliste beim
    /// Verfassen standen zwei Einträge, die der Anwalt nicht auseinanderhalten
    /// kann. Vorbild ist <c>OrdnerStatusOhneGrossKleinschreibung</c>.
    ///
    /// Bestehende Dubletten, die sich nur in der Schreibweise unterscheiden,
    /// lassen den Neuaufbau der Tabelle scheitern. Das ist gewollt: Sie
    /// wortlos zu verschmelzen hiesse, eine der beiden Vorlagen zu löschen.
    /// </summary>
    public partial class BestaendeOhneGrossKleinschreibung : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "Name",
                table: "MailVorlagen",
                type: "TEXT",
                maxLength: 128,
                nullable: false,
                collation: "NOCASE",
                oldClrType: typeof(string),
                oldType: "TEXT",
                oldMaxLength: 128);

            migrationBuilder.AlterColumn<string>(
                name: "Text",
                table: "Grussformeln",
                type: "TEXT",
                maxLength: 128,
                nullable: false,
                collation: "NOCASE",
                oldClrType: typeof(string),
                oldType: "TEXT",
                oldMaxLength: 128);

            migrationBuilder.AlterColumn<string>(
                name: "Weiblich",
                table: "AnredeBausteine",
                type: "TEXT",
                maxLength: 64,
                nullable: false,
                collation: "NOCASE",
                oldClrType: typeof(string),
                oldType: "TEXT",
                oldMaxLength: 64);

            migrationBuilder.AlterColumn<string>(
                name: "Neutral",
                table: "AnredeBausteine",
                type: "TEXT",
                maxLength: 64,
                nullable: false,
                collation: "NOCASE",
                oldClrType: typeof(string),
                oldType: "TEXT",
                oldMaxLength: 64);

            migrationBuilder.AlterColumn<string>(
                name: "Maennlich",
                table: "AnredeBausteine",
                type: "TEXT",
                maxLength: 64,
                nullable: false,
                collation: "NOCASE",
                oldClrType: typeof(string),
                oldType: "TEXT",
                oldMaxLength: 64);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "Name",
                table: "MailVorlagen",
                type: "TEXT",
                maxLength: 128,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "TEXT",
                oldMaxLength: 128,
                oldCollation: "NOCASE");

            migrationBuilder.AlterColumn<string>(
                name: "Text",
                table: "Grussformeln",
                type: "TEXT",
                maxLength: 128,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "TEXT",
                oldMaxLength: 128,
                oldCollation: "NOCASE");

            migrationBuilder.AlterColumn<string>(
                name: "Weiblich",
                table: "AnredeBausteine",
                type: "TEXT",
                maxLength: 64,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "TEXT",
                oldMaxLength: 64,
                oldCollation: "NOCASE");

            migrationBuilder.AlterColumn<string>(
                name: "Neutral",
                table: "AnredeBausteine",
                type: "TEXT",
                maxLength: 64,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "TEXT",
                oldMaxLength: 64,
                oldCollation: "NOCASE");

            migrationBuilder.AlterColumn<string>(
                name: "Maennlich",
                table: "AnredeBausteine",
                type: "TEXT",
                maxLength: 64,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "TEXT",
                oldMaxLength: 64,
                oldCollation: "NOCASE");
        }
    }
}
