# Ghostlog

Automatische urenregistratie voor developers. Ghostlog draait op de achtergrond en detecteert waar je aan werkt — IDE, Git remote, browser. Aan het einde van de dag doe je een korte review; alles is al ingevuld.

## Installeren

```bash
brew tap ghostlog-dev/tap
brew install ghostlog-dev/tap/ghostlog
```

Of download de DMG direct via [GitHub Releases](https://github.com/ghostlog-dev/ghostlog/releases).

## Updaten

```bash
brew upgrade ghostlog
```

## Hoe het werkt

1. Open Ghostlog en log in — je browser koppelt je account automatisch
2. Ghostlog detecteert je actieve IDE, Git remote en browser URL
3. Tracking rules koppelen activiteit automatisch aan het juiste project
4. Installeer de git hook via Instellingen voor extra nauwkeurigheid bij commits
5. Aan het einde van de dag review je je uren in 2 minuten

