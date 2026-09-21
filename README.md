# Scadenzario by DC — Flutter

Progetto Flutter pensato per Android e pronto per essere compilato con Codemagic.
L'app è locale: non usa account, server o sincronizzazione tra dispositivi.

## Funzioni incluse
- Setup iniziale con codice negozio di 4 cifre.
- Nome negozio personalizzabile.
- Logo personalizzabile dalla galleria.
- Home con riepilogo Oggi / Domani / Prossimi 3 giorni.
- Agenda di 14 giorni.
- Inserimento prodotto con nome + data di scadenza.
- Salvataggio locale persistente.
- Modifica/eliminazione dei prodotti.
- Scansione fotocamera di un codice a barre/QR come punto di ingresso per la funzione scanner.
- Grafica chiara pastello verde/rosa coerente con il prototipo approvato.

## Nota importante sulla lettura automatica della data
La versione Flutter include già il flusso scanner e l'inserimento/modifica della scadenza.
La lettura OCR della scritta stampata sulla confezione (nome prodotto + data) è il prossimo punto da rendere robusto su dispositivi reali. Il progetto è strutturato per poter aggiungere un plugin OCR nativo/cloud senza cambiare la logica dell'app.

## Build Android locale
```bash
flutter pub get
flutter build apk --release
```

## Codemagic
Collega il repository Git al progetto Codemagic e usa:
- Flutter build
- Android
- `flutter build apk --release`

Il file generato sarà normalmente:
`build/app/outputs/flutter-apk/app-release.apk`

Per pubblicazione Google Play è preferibile una build AAB:
`flutter build appbundle --release`

## Permessi
La fotocamera è richiesta per la funzione scanner.
Il logo può essere scelto dalla galleria.
