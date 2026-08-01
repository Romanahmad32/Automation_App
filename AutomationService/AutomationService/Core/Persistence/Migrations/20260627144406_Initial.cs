using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AutomationService.Core.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Initial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "FormTemplates",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    TemplateName = table.Column<string>(type: "TEXT", nullable: false),
                    FieldsJson = table.Column<string>(type: "TEXT", nullable: false, defaultValue: "[]"),
                    WordFilePathOhneAuflistung = table.Column<string>(type: "TEXT", nullable: true),
                    WordFilePathMitAuflistung = table.Column<string>(type: "TEXT", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FormTemplates", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "KanzleiSettings",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false),
                    Personentyp = table.Column<string>(type: "TEXT", nullable: false),
                    Name = table.Column<string>(type: "TEXT", nullable: false),
                    StrasseHausnummer = table.Column<string>(type: "TEXT", nullable: false),
                    Postleitzahl = table.Column<string>(type: "TEXT", nullable: false),
                    Ort = table.Column<string>(type: "TEXT", nullable: false),
                    EmailAdresse = table.Column<string>(type: "TEXT", nullable: false),
                    Telefonnummer = table.Column<string>(type: "TEXT", nullable: false),
                    LaufendeAuftragsnummer = table.Column<int>(type: "INTEGER", nullable: false),
                    Abteilung = table.Column<string>(type: "TEXT", nullable: false),
                    TabellenkopfFarbeHex = table.Column<string>(type: "TEXT", nullable: false),
                    AktenStammordner = table.Column<string>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_KanzleiSettings", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Mandanten",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    Anrede = table.Column<string>(type: "TEXT", nullable: false),
                    Vorname = table.Column<string>(type: "TEXT", nullable: false),
                    Nachname = table.Column<string>(type: "TEXT", nullable: false),
                    StrasseHausnummer = table.Column<string>(type: "TEXT", nullable: false),
                    Postleitzahl = table.Column<string>(type: "TEXT", nullable: false),
                    Ort = table.Column<string>(type: "TEXT", nullable: false),
                    EmailAdresse = table.Column<string>(type: "TEXT", nullable: false),
                    Telefonnummer = table.Column<string>(type: "TEXT", nullable: false),
                    Notiz = table.Column<string>(type: "TEXT", nullable: false),
                    ErstelltAm = table.Column<DateTime>(type: "TEXT", nullable: false),
                    AktenOrdnernamenJson = table.Column<string>(type: "TEXT", nullable: false, defaultValue: "[]"),
                    KennzeichenJson = table.Column<string>(type: "TEXT", nullable: false, defaultValue: "[]")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Mandanten", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "ReceivedReplies",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    EmpfangenAm = table.Column<DateTime>(type: "TEXT", nullable: false),
                    Referenz = table.Column<string>(type: "TEXT", nullable: true),
                    Betreff = table.Column<string>(type: "TEXT", nullable: true),
                    RohdatenJson = table.Column<string>(type: "TEXT", nullable: true),
                    Zugeordnet = table.Column<bool>(type: "INTEGER", nullable: false),
                    VorgangId = table.Column<int>(type: "INTEGER", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ReceivedReplies", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Vorgaenge",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    Referenz = table.Column<string>(type: "TEXT", nullable: false),
                    AngefragtAm = table.Column<DateTime>(type: "TEXT", nullable: false),
                    Status = table.Column<string>(type: "TEXT", nullable: false),
                    Rechtsgebiet = table.Column<string>(type: "TEXT", nullable: false),
                    LaufendeNummer = table.Column<int>(type: "INTEGER", nullable: true),
                    Jahr = table.Column<string>(type: "TEXT", nullable: true),
                    Abteilung = table.Column<string>(type: "TEXT", nullable: true),
                    Kennzeichen = table.Column<string>(type: "TEXT", nullable: true),
                    MandantId = table.Column<int>(type: "INTEGER", nullable: true),
                    MandantName = table.Column<string>(type: "TEXT", nullable: true),
                    Gegner = table.Column<string>(type: "TEXT", nullable: true),
                    UnfallDatum = table.Column<string>(type: "TEXT", nullable: true),
                    GeschaedigtenKennzeichen = table.Column<string>(type: "TEXT", nullable: true),
                    Unfallort = table.Column<string>(type: "TEXT", nullable: true),
                    Unfalluhrzeit = table.Column<string>(type: "TEXT", nullable: true),
                    PolizeiVorgangsnummer = table.Column<string>(type: "TEXT", nullable: true),
                    AntwortJson = table.Column<string>(type: "TEXT", nullable: true),
                    DokumentPfad = table.Column<string>(type: "TEXT", nullable: true),
                    AktenOrdner = table.Column<string>(type: "TEXT", nullable: true),
                    AbgeschlossenAm = table.Column<DateTime>(type: "TEXT", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Vorgaenge", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ReceivedReplies_Referenz",
                table: "ReceivedReplies",
                column: "Referenz");

            migrationBuilder.CreateIndex(
                name: "IX_Vorgaenge_Jahr",
                table: "Vorgaenge",
                column: "Jahr");

            migrationBuilder.CreateIndex(
                name: "IX_Vorgaenge_MandantId",
                table: "Vorgaenge",
                column: "MandantId");

            migrationBuilder.CreateIndex(
                name: "IX_Vorgaenge_Referenz",
                table: "Vorgaenge",
                column: "Referenz",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Vorgaenge_Status",
                table: "Vorgaenge",
                column: "Status");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "FormTemplates");

            migrationBuilder.DropTable(
                name: "KanzleiSettings");

            migrationBuilder.DropTable(
                name: "Mandanten");

            migrationBuilder.DropTable(
                name: "ReceivedReplies");

            migrationBuilder.DropTable(
                name: "Vorgaenge");
        }
    }
}
