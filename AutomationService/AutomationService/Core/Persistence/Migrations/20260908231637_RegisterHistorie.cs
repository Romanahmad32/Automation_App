using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AutomationService.Core.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class RegisterHistorie : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "RegisterHistorie",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    Kennung = table.Column<string>(type: "TEXT", maxLength: 64, nullable: false),
                    Jahr = table.Column<int>(type: "INTEGER", nullable: false),
                    LaufendeNummer = table.Column<int>(type: "INTEGER", nullable: false),
                    NummerZusatz = table.Column<string>(type: "TEXT", maxLength: 16, nullable: false),
                    Spalte1 = table.Column<string>(type: "TEXT", maxLength: 32, nullable: false),
                    Aktenzeichen = table.Column<string>(type: "TEXT", maxLength: 64, nullable: false),
                    Abteilung = table.Column<string>(type: "TEXT", maxLength: 16, nullable: false),
                    AbteilungRoh = table.Column<string>(type: "TEXT", maxLength: 32, nullable: false),
                    Sachart = table.Column<string>(type: "TEXT", maxLength: 128, nullable: false),
                    Mandant = table.Column<string>(type: "TEXT", maxLength: 256, nullable: false),
                    Gegner = table.Column<string>(type: "TEXT", maxLength: 256, nullable: false),
                    Sachbestand = table.Column<string>(type: "TEXT", maxLength: 512, nullable: false),
                    Unfalldatum = table.Column<string>(type: "TEXT", maxLength: 32, nullable: false),
                    Rechtsgebiet = table.Column<string>(type: "TEXT", maxLength: 128, nullable: false),
                    Freitext = table.Column<string>(type: "TEXT", nullable: false),
                    Sicherheit = table.Column<string>(type: "TEXT", maxLength: 16, nullable: false),
                    HinweiseJson = table.Column<string>(type: "TEXT", nullable: false, defaultValue: "[]"),
                    BefundeJson = table.Column<string>(type: "TEXT", nullable: false, defaultValue: "[]"),
                    MandantId = table.Column<int>(type: "INTEGER", nullable: true),
                    Quelle = table.Column<string>(type: "TEXT", maxLength: 32, nullable: false),
                    ImportiertAm = table.Column<DateTime>(type: "TEXT", nullable: false),
                    GeaendertAm = table.Column<DateTime>(type: "TEXT", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RegisterHistorie", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_RegisterHistorie_Jahr",
                table: "RegisterHistorie",
                column: "Jahr");

            migrationBuilder.CreateIndex(
                name: "IX_RegisterHistorie_Jahr_LaufendeNummer_NummerZusatz",
                table: "RegisterHistorie",
                columns: new[] { "Jahr", "LaufendeNummer", "NummerZusatz" },
                unique: true,
                filter: "LaufendeNummer > 0");

            migrationBuilder.CreateIndex(
                name: "IX_RegisterHistorie_Kennung",
                table: "RegisterHistorie",
                column: "Kennung",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "RegisterHistorie");
        }
    }
}
