# Outlook-/Microsoft-Postfach anbinden (einmalige Entwickler-Einrichtung)

> **Dieser Weg gilt nur, wenn das Postfach wirklich bei Microsoft liegt** (Outlook.com,
> Hotmail, Microsoft 365) — nicht schon dann, wenn es mit Outlook *gelesen* wird. Liegt es
> bei einem anderen Anbieter (1&1/IONOS, Gmail), ist Outlook nur ein Client daneben und es
> gilt der IMAP-Weg. Welcher Fall vorliegt, klärt
> [`docs/POSTFACH_SETUP.md`](POSTFACH_SETUP.md) in zwei Minuten.

Microsoft hat IMAP mit Passwort/App-Passwort im September 2024 endgültig abgeschaltet.
Outlook.com-, Hotmail- und Microsoft-365-Postfächer lassen sich deshalb nur noch über
OAuth2 („Mit Microsoft anmelden“) überwachen. Für den **Anwalt** ist das der einfachste
Weg: Er klickt in den Einstellungen auf „Mit Microsoft anmelden“, meldet sich einmal im
Browser an — fertig. Kein App-Passwort, keine Servereinstellungen.

Damit dieser Knopf funktioniert, muss **einmalig vom Entwickler** (nicht vom Kunden)
eine kostenlose Azure-App-Registrierung angelegt und deren Client-ID in der App
hinterlegt werden.

## 1. App-Registrierung anlegen (einmalig, ~5 Minuten)

1. <https://portal.azure.com> öffnen und anmelden (ein kostenloses Microsoft-Konto genügt;
   es ist **kein** kostenpflichtiges Azure-Abo nötig).
2. **Microsoft Entra ID → App-Registrierungen → Neue Registrierung**.
3. Eingaben:
   - **Name:** z. B. `Kanzlei Automation App`
   - **Unterstützte Kontotypen:** „Konten in einem beliebigen Organisationsverzeichnis
     und persönliche Microsoft-Konten“ (deckt Outlook.com/Hotmail **und** Microsoft 365 ab)
   - **Umleitungs-URI:** Plattform **„Mobile Anwendungen und Desktopanwendungen“** wählen
     und `http://localhost` eintragen.
4. **Registrieren** klicken.
5. Auf der Übersichtsseite die **Anwendungs-ID (Client-ID)** kopieren (GUID).

Berechtigungen: Die App fordert zur Laufzeit zwei delegierte Scopes an —
`https://outlook.office365.com/IMAP.AccessAsUser.All` zum Empfangen und
`https://outlook.office365.com/SMTP.Send` zum Versenden (§4.7); der Nutzer stimmt bei der
ersten Anmeldung selbst zu. Ein Eintrag unter „API-Berechtigungen“ ist dafür bei
persönlichen Konten nicht zwingend; für Microsoft-365-Organisationskonten schadet es
nicht, die delegierten Berechtigungen **IMAP.AccessAsUser.All** und **SMTP.Send**
(Office 365 Exchange Online) zusätzlich einzutragen.

> **Nach einem Update, das einen Scope ergänzt, muss sich der Anwalt einmalig neu
> anmelden.** MSAL holt für einen Scope, dem noch nie zugestimmt wurde, kein stilles
> Token; bis zur Neuanmeldung meldet der Postfach-Status „Microsoft-Anmeldung
> erforderlich …“ und der Versand schlägt mit demselben Hinweis fehl. Genau das ist beim
> Sprung von „nur Empfang“ auf „Empfang und Versand“ passiert.

## 2. Client-ID in der App hinterlegen

In `AutomationService/AutomationService/appsettings.json`:

```json
"Mailbox": {
  "MicrosoftClientId": "<die kopierte Client-ID>"
}
```

Ohne diese ID blendet die Oberfläche den Outlook-Weg zwar ein, meldet aber beim
Anmelden einen klaren Fehler.

## 3. Was der Kunde später macht (der einfache Teil)

1. Einstellungen → Postfach-Zugang → Anbieter **„Outlook / Microsoft“** wählen.
2. **„Mit Microsoft anmelden“** klicken — der normale Browser öffnet sich.
3. Mit der Outlook-Adresse und dem **normalen Kontopasswort** anmelden und zustimmen.
4. Fertig: Adresse und Server werden automatisch übernommen, die Überwachung verbindet
   sich sofort. Die Anmeldung bleibt dauerhaft gültig (verschlüsselter Token-Cache unter
   `%APPDATA%\AutomationService\msal_token_cache.bin`) und erneuert sich still.

„Abmelden“ in den Einstellungen entfernt die gespeicherten Tokens wieder.

## Technischer Hintergrund

- MSAL.NET (`Microsoft.Identity.Client`) holt die Tokens; der Datei-Cache ist unter
  Windows DPAPI-verschlüsselt (`Microsoft.Identity.Client.Extensions.Msal`).
- Der Monitor meldet sich per MailKit `SaslMechanismOAuth2` (XOAUTH2) an
  `outlook.office365.com:993` an; Zugriffstokens werden vor jedem Verbindungsaufbau
  still erneuert (`AcquireTokenSilent`). Der Versand nutzt dieselben Tokens gegen
  `smtp.office365.com:587` (STARTTLS). Passt der abgeleitete Servername nicht — private
  Outlook.com-Konten senden über `smtp-mail.outlook.com` —, lässt er sich in
  `appsettings.json` unter `EmailVersand:SmtpHost` überschreiben.
- Läuft das Refresh-Token ab (z. B. Passwortwechsel, Konto entzogen), zeigt der
  Postfach-Status „Microsoft-Anmeldung erforderlich …“ — ein erneuter Klick auf
  „Mit Microsoft anmelden“ genügt.
