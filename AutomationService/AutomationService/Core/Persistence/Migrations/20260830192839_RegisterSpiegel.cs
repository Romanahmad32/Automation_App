using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AutomationService.Core.Persistence.Migrations
{
    /// <summary>
    /// Die vier Einstellungen des Register-Spiegels (§6.2, #40).
    ///
    /// Neue Spalten kommen mit leerem String bzw. false in eine bestehende
    /// Installation. Fuer den Ablageordner ist das richtig — der ist ein Pfad
    /// auf einem fremden Rechner und darf nicht geraten werden. Fuer Dateiname,
    /// Filter und Schalter ist es falsch: Dort wuerde eine bestehende
    /// Installation stumm anders eingestellt sein als eine frische, obwohl
    /// beide dasselbe meinen. Deshalb der Nachtrag unten. Er ist gefahrlos,
    /// solange kein Ablageordner gesetzt ist: ohne Ziel schreibt der Spiegel
    /// ohnehin nicht.
    /// </summary>
    public partial class RegisterSpiegel : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "RegisterAblageOrdner",
                table: "KanzleiSettings",
                type: "TEXT",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "RegisterDateiname",
                table: "KanzleiSettings",
                type: "TEXT",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "RegisterExportFilter",
                table: "KanzleiSettings",
                type: "TEXT",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<bool>(
                name: "RegisterNachAbschlussSchreiben",
                table: "KanzleiSettings",
                type: "INTEGER",
                nullable: false,
                defaultValue: false);

            migrationBuilder.Sql(
                """
                UPDATE KanzleiSettings
                SET RegisterDateiname = 'Sachgebiete-Register (App)',
                    RegisterExportFilter = 'alle',
                    RegisterNachAbschlussSchreiben = 1
                WHERE Id = 1;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "RegisterAblageOrdner",
                table: "KanzleiSettings");

            migrationBuilder.DropColumn(
                name: "RegisterDateiname",
                table: "KanzleiSettings");

            migrationBuilder.DropColumn(
                name: "RegisterExportFilter",
                table: "KanzleiSettings");

            migrationBuilder.DropColumn(
                name: "RegisterNachAbschlussSchreiben",
                table: "KanzleiSettings");
        }
    }
}
