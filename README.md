# Pigeon Rush

Un piccione vola contromano in autostrada: schiva camion, cartelli e cavalcavia, centra i mezzi con la cacca per guadagnare velocità e punti.

**Stack:** Godot 4.7.2 · GDScript tipizzato · renderer Mobile · mobile (Android, poi iOS); PC solo per sviluppo

> Fino al tag `csharp-final` il gioco era in C#/.NET. È passato a GDScript perché l'export C# per Android e iOS è ancora sperimentale in Godot, mentre i plugin per pubblicità, Play Giochi e acquisti si usano direttamente da GDScript.

## Come avviarlo

1. Installa **Godot 4.7.x standard** (non serve più la versione .NET né l'SDK .NET).
2. Apri `project.godot` dal Project Manager di Godot.
3. Premi **F5**.

**Tipi obbligatori:** nelle impostazioni del progetto una variabile o un parametro senza tipo è un errore (`untyped_declaration`), e gli accessi non sicuri sono segnalati come avviso.

**Prova automatica**, senza interfaccia. Fa due partite da circa 150 s simulati ciascuna:
- volo pseudo-casuale, con gli impatti ignorati per passare da gallerie e cantieri;
- in ogni partita un Continua con la pubblicità finta, poi la fine e "Try again", che ricarica la scena;
- prima di partire, controlla le regole della pubblicità a schermo intero e il salvataggio JSON.

Termina con `[Smoke] OK` se non ci sono errori, altrimenti stampa gli errori ed esce con codice 1. Non tocca il record salvato.

```
godot --headless --path . --fixed-fps 60 -- --smoke-test
```

Opzioni (dopo `--`):
- `--shots`, con un driver video (non `--headless`): salva in `user://` una schermata ogni 6 s e una per ogni stato (countdown, impatto, "Continue?", pubblicità, game over);
- `--survive=20`: impatti ignorati solo per i primi 20 s, per partite più brevi;
- `--no-ads`: simula la mancanza di pubblicità, quindi niente pannello "Continue?" (funziona anche giocando normalmente).

## Comandi

| Azione | Tastiera | Gamepad | Touch |
|---|---|---|---|
| Volare | WASD / frecce | Stick sinistro / D-pad | Joystick flottante (metà sinistra) |
| Sganciare | Spazio / J | A / grilletto destro | Tocco sulla metà destra |
| Pausa | Esc / P | Start | Pulsante "II" |

## Regole

- **Mirino automatico:** quando sei sopra un mezzo nella sua corsia, sul tetto compare un anello giallo. Sgancia in quel momento e la cacca lo intercetta.
- **Boost:** ogni mezzo centrato aggiunge 1 stack di velocità (+12%, max 5). Cabrio e "auto appena lavata" ne danno 2. Ogni stack dura 3.5 s.
- **Combo:** colpi consecutivi entro 3.5 s moltiplicano i punti (fino a x5). Anche un passaggio a filo tiene viva la combo.
- **Punti distanza:** metri × moltiplicatore di velocità × **1.5 se voli radente** (sotto i 2 m).
- **Passaggio a filo:** sfiorare un ostacolo a meno di 0.9 m senza toccarlo vale 50 × combo.
- **Countdown:** ogni partita parte con 3-2-1-GO. Durante il countdown il piccione si può già spostare, ma non sgancia e non fa punti.
- **Un colpo e sei fuori:** al primo impatto con un mezzo o un ostacolo il piccione è spacciato. Niente vite.
- **Continua (1 per partita):** dopo l'impatto compare "Continue?" con un anello di 5 s. Guardando la pubblicità a premio si riparte con lo stesso punteggio e la stessa distanza:
  - spariscono mezzi e strutture nei 70 m davanti (le gallerie restano, si vola sotto il soffitto);
  - nuovo countdown col mondo fermo, poi ripartenza dolce;
  - 2.5 s di invulnerabilità, con il piccione che lampeggia.

  Se la pubblicità viene saltata non c'è premio e l'offerta riprende. "No thanks", Esc o la fine dell'anello portano al game over.
- **Pubblicità a schermo intero:** può arrivare premendo "Try again", mai nelle prime 3 partite della sessione, al massimo una ogni 3 partite, almeno 90 s dopo qualsiasi altra pubblicità e mai dopo una partita in cui si è guardata quella a premio.
- **Munizioni:** si parte con 6 cacche (max 10). Le **briciole** ne ricaricano 3. Il contatore sta in basso al centro (icone + `6/10`, rosso lampeggiante quando è vuoto) e, su touch, anche sul pulsante DROP.
- **Abbaglianti:** se sei sulla traiettoria di un mezzo (stessa corsia, sotto il tetto) tra 15 e 85 m, ti lampeggia 2-3 volte. Lampeggia solo il primo mezzo della corsia: quelli dietro non ti vedono.
- **Cambi di corsia:** ogni tanto un mezzo mette la freccia (1.5 s) e si sposta nella corsia accanto. È raro (ogni 10-19 s all'inizio, 6-11 s a difficoltà massima) e leale: parte solo da mezzi a 3.5-5.5 s dal piccione, solo se nella corsia di destinazione c'è spazio, mai verso una corsia chiusa da un cantiere e mai se chiuderebbe il varco minimo garantito.
- **Gallerie (320-560 m):** soffitto a 5.6 m e ventilatori appesi, quindi niente volo alto. All'interno è buio: si vedono lampade, fari e abbaglianti. La camera si abbassa da sola prima del portale.
- **Lavori:** chiudono la corsia sinistra o destra per 160-240 m. Le due estremità sono speculari (cartello, carrello con freccia, coni e rete in diagonale): una verso il piccione e una verso le auto, che sono quelle a cui serve davvero la chiusura. Un ponteggio con rete arancione alto 8 m (più del volo massimo) impedisce di passarci sopra: la strada si stringe davvero a due corsie, con tutto il traffico lì. La rete è un muro morbido (ti spinge, non ti uccide) e segue la diagonale dei coni. I carrelli con la freccia sono invece ostacoli veri: se sei nella corsia chiusa, spostati prima.
- **Difficoltà:** la velocità base sale da 16 a 30 m/s; più camion e file piene nei primi 150 s.

## Architettura

Tutta la scena viene costruita **da codice** (`Scenes/Main.tscn` contiene solo il nodo radice): niente `.tscn` o `.tres` da mantenere a mano. Mesh low-poly generati proceduralmente con vertex color (1 materiale = poche draw call su mobile).

```
Scripts/
├── main.gd                  Regista: costruzione scena, stati di gioco (countdown, Continua), ordine di update, prova automatica
├── Core/
│   ├── game_config.gd       Tutte le costanti di bilanciamento
│   ├── game_session.gd      Stato partita (munizioni, tempo, difficoltà, game over)
│   ├── speed_controller.gd  Velocità base + boost cumulabili
│   ├── score_service.gd     Punteggio, combo, statistiche
│   ├── cells.gd             Griglia 3 corsie × 3 fasce (bitmask) per il varco garantito
│   ├── node_pool.gd         Pool generico di nodi
│   ├── actions.gd           Input map registrata via codice
│   └── save_data.gd         Salvataggio JSON con versione (record, partite giocate, impostazioni)
├── Ads/
│   ├── ad_service.gd        Contratto delle pubblicità (a premio e a schermo intero)
│   ├── mock_ad_service.gd   Pubblicità finta da 2 s per PC e prove (si può saltare)
│   ├── interstitial_policy.gd  Quando mostrare quella a schermo intero
│   └── ads.gd               Accesso statico: il servizio vive fuori dalla scena e sopravvive a "Try again"
├── Rendering/
│   ├── low_poly_builder.gd  Primitive → ArrayMesh flat-shaded con vertex color
│   ├── asset_warmup.gd      Pre-costruzione mesh e pre-compilazione shader durante il menu
│   └── palette.gd           Colori e materiali condivisi
├── Player/
│   ├── pigeon_controller.gd Movimento X/Y con inerzia, inclinazione, caduta finale
│   ├── pigeon_model.gd      Piccione procedurale con ali animate
│   └── poop_system.gd       Mirino, traiettoria d'intercetto, macchie
├── World/
│   ├── traffic_spawner.gd   File di traffico, strutture, raccoglibili, collisioni
│   ├── hazard.gd            Base ostacoli (AABB manuali, sweep anti-tunneling)
│   ├── vehicle.gd / vehicle_catalog.gd / vehicle_meshes.gd   (auto, furgoni, camion, bus, cabrio)
│   ├── high_beam_visuals.gd Bagliori e coni additivi degli abbaglianti (nessuna luce dinamica)
│   ├── indicator_visuals.gd Frecce gialle lampeggianti per i cambi di corsia
│   ├── ambient_traffic.gd   Traffico scenografico sulla carreggiata opposta
│   ├── sign_gantry.gd       Portali con cartelli verdi svizzeri
│   ├── overpass.gd          Cavalcavia
│   ├── tunnel.gd / tunnel_meshes.gd          Gallerie a doppia canna (buio, soffitto, ventilatori)
│   ├── road_works.gd / road_works_meshes.gd  Cantieri con corsia chiusa e macchinari
│   ├── pickup.gd            Briciole (ricarica cacca)
│   ├── road_scroller.gd / road_meshes.gd     Strada a segmenti riciclati
│   ├── structure_meshes.gd
│   └── scenery_factory.gd   Cielo, sole, nebbia, montagne
├── Audio/game_audio.gd      Pool di player 2D/3D, loop d'ambiente, bus World/Ambience/UI, riverbero in galleria
├── CameraRig/chase_camera.gd Inseguimento, FOV dinamico, shake
├── Effects/                 Testi fluttuanti, esplosione di piume
└── UI/                      HUD, controlli touch, schermate (titolo, pausa, "Continue?", game over, countdown)
```

Convenzioni GDScript: file in `snake_case`, `class_name` in `PascalCase`, costanti in `MAIUSCOLO`, eventi come **segnali** (`pigeon_hit`, `vehicle_warned`…), cache statiche con `static var`.

### Scelte chiave

- **Mondo "tapis roulant":** il piccione resta a Z = 0. Strada e strutture scorrono alla velocità del piccione, i mezzi a velocità piccione + traffico. Niente problemi di precisione dei float e il boost è solo un moltiplicatore.
- **Varco garantito:** ogni fila lascia almeno 2 celle libere su 9, e almeno una è adiacente a una cella libera della fila precedente. Le strutture (portali, cavalcavia) che arrivano nello stesso istante vengono incluse nel calcolo.
- **Collisioni manuali AABB** con sweep sull'asse Z: deterministiche, economiche, nessun "salto" dell'ostacolo ad alta velocità.
- **Guida a destra:** i mezzi contromano (verso +Z) hanno lo spartitraffico alla loro sinistra, quindi la carreggiata opposta sta sul lato +X. Lì il traffico va nella stessa direzione del piccione: a inizio partita ti sorpassa, quando acceleri sei tu a superarlo.
- **Strutture lunghe** (gallerie, cantieri): nel calcolo del varco conta l'intervallo [fronte, coda], non un singolo istante. Un mezzo non viene generato nella corsia chiusa se raggiungerebbe il cantiere prima di uscire dalla visuale.
- **Niente scatti alla prima comparsa:** tutti i mesh procedurali (gallerie, cantieri, veicoli…) vengono costruiti durante il menu, uno per frame, e disegnati una volta in miniatura dietro al pannello del titolo, così geometria e shader sono già pronti quando parte la partita. In più l'export Android ha lo **Shader Baker** attivo.
- **Audio sintetizzato:** tutti gli effetti (`Audio/sfx/*.wav`, 44.1 kHz mono) sono generati da `Tools/synth_sfx.py` (numpy/scipy), niente asset esterni. I passaggi dei mezzi hanno il Doppler già nel file, quindi il Doppler di Godot è spento; i loop (strada, vento, galleria) sono senza cucitura e vengono messi in loop a runtime.
- **Mesh veloci anche in GDScript:** `LowPolyBuilder` tiene in cache le forme unitarie già espanse in triangoli con la normale di faccia, e le trasforma con `Transform3D * PackedVector3Array` (codice nativo, nessun ciclo per vertice). I 60 mesh del gioco si costruiscono in circa 30 ms.
- **Ordine di update esplicito** in `main.gd` (`_tick_playing`): niente dipendenze dall'ordine dei `_process`.

## Struttura di gioco e monetizzazione

### Decisioni prese

- **Solo mobile:** Android prima, iOS in un secondo momento. Tastiera e gamepad restano solo per sviluppare e provare su PC, senza versione PC pubblicata.
- **Pubblico 13+:** niente programma Famiglie di Google Play. Grafica e testi restano coerenti con un pubblico di adolescenti e adulti.
- **Volo continuo diviso in tratte**, senza livelli. Il record si batte in un'unica corsa, e le tratte danno il senso di progresso.
- **Un solo "Continua" con pubblicità a premio per partita.**
- **Server proprio su Infomaniak:** una nuova VPS dedicata ai giochi (1 vCPU / 2 GB per iniziare, da scalare quando il monitoraggio lo indica) con un dominio dedicato, condivisa da tutti i giochi. Ospita API, classifica mondiale, informativa privacy e pagina di cancellazione account. Tutto gira in **Docker Compose**.

### Perché il volo continuo e non i livelli

| | Livelli | Volo continuo a tratte (scelto) |
|---|---|---|
| Lavoro | Livelli da disegnare e bilanciare uno per uno | La generazione procedurale c'è già |
| Morte al primo colpo | Frustrante: si ripete il livello | Naturale: "batti il tuo record" |
| "Continua" con pubblicità | Ha poco senso (tanto vale ricominciare il livello) | Ha senso: il giocatore sta perdendo un record |
| Spazi per la pubblicità | Pochi (tra i livelli) | A ogni morte |
| Meteo e giorno/notte | Fissi per livello | Cambiano durante il volo, all'uscita delle gallerie |

### Il viaggio sulla A2

Il volo è un viaggio a tratte reali: **Chiasso → Lugano → Bellinzona → Gottardo → Lucerna → Zurigo → Basilea**, poi si ricomincia a difficoltà più alta.

*Variante da valutare:* al **bivio di Bellinzona** il giocatore sceglie la strada volando nelle corsie di sinistra o di destra: A2 verso il Gottardo oppure **A13 verso il San Bernardino** (Roveredo → Mesocco → galleria del San Bernardino → Thusis → Coira).

- All'inizio di ogni tratta compare un cartello ("Welcome to Canton Uri") e si riceve un piccolo bonus.
- Meteo e ora del giorno cambiano all'uscita delle gallerie (vedi l'idea più sotto). Notte e nebbia danno un moltiplicatore di punti.
- Il record diventa anche "fin dove sei arrivato" su una mini mappa.
- Ci sono **missioni giornaliere** ("colpisci 5 bus", "vola 1 km di notte"), che portano il giocatore a fare più partite.

### Pubblicità

| Formato | Quando | Regole |
|---|---|---|
| **A premio: Continua** | Alla morte: pannello "Continue?" con conto alla rovescia di 5 s | **1 per partita.** Il pulsante compare solo se la pubblicità è già caricata |
| **A premio: doppio bottino** | Schermata di game over | Raddoppia le briciole d'oro della partita |
| **A premio: partenza potenziata** | Menu | Per esempio "parti con 10 cacche" |
| **A schermo intero** | Solo al game over | Ogni 3 partite circa, mai nelle prime 3, almeno 90 s tra una e l'altra, mai subito dopo una pubblicità a premio, mai durante il volo |
| Banner | Nessuno | Rendono poco e rovinano l'aspetto del gioco |

Le frequenze sono valori di partenza, da calibrare con i dati reali.

**Flusso del Continua:**
1. Schianto e rallentatore fino a fermarsi, poi il pannello con l'anello di 5 s e i pulsanti "Watch ad & fly on" / "No thanks".
2. Durante la pubblicità l'anello si ferma e l'audio del gioco è spento.
3. Se la pubblicità viene vista fino in fondo:
   - spariscono mezzi e strutture nei 70 m davanti al piccione (le gallerie restano);
   - parte il countdown 3-2-1 col mondo fermo, poi il mondo riaccelera in circa 0.8 s;
   - il piccione è invulnerabile per 2.5 s e lampeggia;
   - punteggio, distanza, velocità di base, tratta e meteo restano quelli di prima (boost e combo si perdono con l'impatto).
4. Se la pubblicità viene saltata non c'è premio e l'offerta riprende col tempo rimasto. Se la pubblicità non è disponibile il pannello non compare e si va dritti al game over.
5. La pubblicità a premio si **carica in anticipo durante il volo**, non dopo la morte (con quella vera, Fase 7).

### Briciole d'oro e un eventuale secondo Continua

Le **briciole d'oro** sono la valuta di gioco. Si guadagnano volando: sono raccoglibili rari, si ottengono convertendo la distanza a fine partita, completando missioni e con il "doppio bottino". Servono a comprare skin del piccione.

Il secondo Continua, se lo si aggiunge, **va pagato con le briciole d'oro e non direttamente con soldi veri**:

| | Briciole d'oro | Soldi veri (es. CHF 0.99 a Continua) |
|---|---|---|
| Percezione | "Me lo sono guadagnato" | "Pay to win", recensioni negative |
| Conversione | Alta: chiunque gioca ne ha | Bassissima: pochi pagano nel momento della morte |
| Tecnica | Solo dati salvati in locale | Google Play Billing con un acquisto consumabile a ogni morte |
| Ricavi | Indiretti: il giocatore guarda più pubblicità "doppio bottino" e forse compra pacchetti di briciole | Diretti ma rari |

Proposta: il secondo Continua costa per esempio 150 briciole e c'è un massimo di 2 Continua per partita (1 con pubblicità + 1 con briciole). Il prezzo va bilanciato con quanto si guadagna in una partita media. I soldi veri entrano solo da **"Rimuovi pubblicità"** (acquisto una tantum) e, in seguito, eventualmente da **pacchetti di briciole**. *Da decidere più avanti, con l'economia già in funzione.*

### Classifica mondiale e identità del giocatore

**Obiettivo:** a ogni morte la partita viene inviata al server. Il game over mostra la posizione nel mondo ("#1234 in the world", "NEW WORLD RECORD!") e si può aprire la classifica.

**Come si riconosce il giocatore, senza registrazione.** Si combinano due sistemi:

| | Account anonimo del gioco | Google Play Games Services v2 (facoltativo) |
|---|---|---|
| Cos'è | Al primo avvio il server crea un giocatore e restituisce un ID e un token segreto, salvati sul telefono | Accesso automatico all'avvio, senza schermate: dà un ID giocatore Google e il nome del profilo Play Giochi |
| Pro | Funziona sempre, anche senza Play Giochi e su iOS | Il giocatore ritrova l'account dopo una reinstallazione o su un telefono nuovo; l'identità è verificabile dal server |
| Contro | Se l'app viene disinstallata l'account si perde | Non tutti usano Play Giochi; su iOS serve Game Center a parte |

**Flusso:**
1. Primo avvio: il gioco crea l'account anonimo. Il nome di default è quello di Play Giochi, oppure `Pigeon1234`, e si può cambiare nelle impostazioni.
2. Se Play Giochi è attivo, il gioco chiede un codice monouso (`requestServerSideAccess`) e lo invia al server. Il server lo scambia con Google, verifica l'ID del giocatore con le API di Play Games e lo **collega** all'account. Con un telefono nuovo, lo stesso ID ritrova il vecchio account.
3. Nome visibile in classifica: filtro delle parolacce e un suffisso `#1234` se il nome è già usato.

**Server (stesso stack degli altri progetti):** ASP.NET Core (.NET 10) minimal API + **PostgreSQL** + Dapper, con HTTPS, sul server Infomaniak. È unico per tutti i giochi: ogni gioco ha il suo identificativo.

| Endpoint | Cosa fa |
|---|---|
| `POST /v1/players` | Crea l'account anonimo e restituisce ID e token |
| `POST /v1/players/me/google` | Collega Play Giochi (codice monouso) |
| `PATCH /v1/players/me` | Cambia il nome |
| `POST /v1/games/{game}/runs` | Invia una partita (punti, distanza, durata, colpi, tratta, continue usati, versione) e restituisce posizione, record personale e record mondiale |
| `GET /v1/games/{game}/leaderboards/{all\|week\|day}` | Classifica: primi 100 + "intorno a me" |
| `DELETE /v1/players/me` | Cancella account e dati (richiesto da Google Play) |

Tabelle: `games`, `players`, `player_identities` (provider + ID esterno), `runs`, `best_scores` (migliore per gioco, giocatore e periodo).

**Perché PostgreSQL (scelto).** Lo conosci, gira in un container accanto all'API, ha transazioni, upsert e indici, e regge senza problemi i volumi di un gioco indie. La regola è non calcolare mai la classifica sulla tabella `runs`, ma su `best_scores`: un record per gioco, periodo e giocatore, aggiornato solo quando il punteggio migliora.

```sql
CREATE TABLE best_scores (
    game_id     smallint    NOT NULL,
    period      text        NOT NULL,   -- 'all', 'w2026-47', 'd2026-11-17'
    player_id   uuid        NOT NULL,
    score       bigint      NOT NULL,
    run_id      bigint      NOT NULL,
    achieved_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (game_id, period, player_id)
);
CREATE INDEX ix_best_rank ON best_scores (game_id, period, score DESC, achieved_at);

-- aggiorna solo se il nuovo punteggio è migliore
INSERT INTO best_scores (game_id, period, player_id, score, run_id)
VALUES (@GameId, @Period, @PlayerId, @Score, @RunId)
ON CONFLICT (game_id, period, player_id)
DO UPDATE SET score = EXCLUDED.score, run_id = EXCLUDED.run_id, achieved_at = now()
WHERE EXCLUDED.score > best_scores.score;

-- posizione = quanti hanno fatto meglio + 1
SELECT COUNT(*) + 1 FROM best_scores WHERE game_id = @GameId AND period = @Period AND score > @Score;
```

I periodi scaduti si cancellano con un job notturno. Se un giorno i numeri lo richiedessero, si possono aggiungere una posizione approssimata ("Top 12%") per chi è molto in basso e **Redis/Valkey come cache**, con Postgres che resta la fonte di verità. Le alternative scartate:
- **SQLite:** scrive una cosa per volta;
- **MySQL:** non dà nulla in più;
- **MongoDB:** i dati sono relazionali.

### Server: repository e pipeline

**Repository separato** (es. `game-services`), non dentro il progetto Godot, per tre motivi:
- Il server è C#/.NET, il gioco GDScript: progetti e strumenti diversi.
- Il server è condiviso da tutti i giochi: non appartiene a Pigeon Rush.
- Versioni e rilasci sono indipendenti: si aggiorna il server senza ripubblicare il gioco, e viceversa.

```
game-services/
├── src/GameServices.Api/          Minimal API, Dapper, autenticazione con token
├── src/GameServices.Migrations/   Script SQL numerati (DbUp), eseguiti al deploy
├── tests/GameServices.Tests/      Test con Testcontainers (Postgres vero)
├── deploy/                        compose.yml, Caddyfile, deploy.sh, configurazione di Postgres
└── .github/workflows/deploy.yml
```

Nel gioco va solo il client: `Scripts/Online/game_services_client.gd` (con `HTTPRequest`), con le strutture dei messaggi riprese dall'API. Sono poche e l'API è versionata (`/v1`).

**Hosting: nuova VPS Infomaniak dedicata ai giochi (1 vCPU / 2 GB) con Docker Compose.** Docker aggiunge un livello, ma porta vantaggi concreti:
- ogni servizio è isolato e descritto in un file;
- aggiungere servizi in futuro (Redis, worker, dashboard) è banale;
- spostarsi su una VPS più grande vuol dire copiare la cartella e i volumi.

```
/opt/game-services/compose.yml
├── caddy           reverse proxy, HTTPS automatico (Let's Encrypt)      ~30 MB
├── api             ASP.NET Core, limite memoria 512 MB                  ~100-200 MB
├── postgres        postgres:17, limite 768 MB, volume persistente       ~150-400 MB
├── backup          pg_dump notturno → kDrive, tiene 14 giorni           quasi 0
└── beszel-agent    metriche di server e container per il monitoraggio   ~10 MB
```

Configurazione per 2 GB di RAM:
- Postgres configurato per 2 GB: `shared_buffers=256MB`, `effective_cache_size=768MB`, `max_connections=30`;
- pool di connessioni Npgsql piccolo;
- 1-2 GB di swap come rete di sicurezza.

**Monitoraggio e avvisi.** Si usa **Beszel**, leggero, con statistiche per container e avvisi via email, Telegram, ntfy o webhook:
- l'**hub** (la dashboard) gira sull'**altra** VPS (`nikigagliardi.ch`), così se il server dei giochi si spegne l'avviso arriva lo stesso;
- sul server dei giochi gira solo l'**agent**;
- il **gioco non dipende dal server**: se l'API non risponde si gioca comunque, e le partite restano in coda.

| Avviso | Soglia di partenza | Cosa vuol dire |
|---|---|---|
| Server irraggiungibile | 2 minuti | VPS o rete giù |
| CPU | > 80% per 10 minuti | Tempo di passare a 2 vCPU |
| RAM | > 85% per 10 minuti | Tempo di passare a 4 GB (o di ridurre la memoria di Postgres) |
| Disco | > 80% | Pulire log e backup o ingrandire il disco |
| API `/health` | non risponde per 2 minuti | Container fermo o in errore |

**Scalare:** quando gli avvisi diventano frequenti si passa alla VPS più grande. Se serve, Postgres si sposta su una macchina sua: basta cambiare la stringa di connessione dell'API.

**Pipeline (GitHub Actions)**, a ogni push su `main`:
1. build + test, con Postgres in un container del runner;
2. build dell'immagine Docker dell'API, con tag = commit;
3. trasferimento al server via SSH (`docker save | gzip | ssh … docker load`), senza registro esterno e senza limiti di spazio del piano gratuito;
4. sul server, `deploy.sh <tag>`:
   - esegue le migrazioni del database (DbUp);
   - aggiorna il tag in `.env` e lancia `docker compose up -d api`;
   - controlla `/health`: se fallisce, torna al tag precedente;
5. il server tiene le ultime 5 immagini, così il ripristino è immediato.

Il server ha un utente `deploy` con chiave SSH dedicata (salvata nei secret di GitHub) che può usare Docker solo nella cartella del servizio.

*In seguito, per il gioco:* una seconda pipeline che esporta l'AAB Android con Godot in modalità headless e lo carica nel test interno di Play Console.

**Dettagli importanti:**
- **Mai bloccare il gioco:** l'invio parte al game over con un timeout di circa 3 s, mostrando "Saving…". Senza rete la partita va in una coda locale e viene reinviata al prossimo avvio. "Try again" funziona sempre.
- **Anti-trucchi:**
  - controlli di plausibilità sul server: punti compatibili con distanza e colpi, distanza compatibile con la durata e la velocità massima, punti al secondo entro un limite;
  - limite di richieste;
  - le partite sospette vengono segnalate, non mostrate.
  - Un segreto nel client non basta, perché si estrae dall'APK. In seguito si può aggiungere la **Play Integrity API**.
- **Privacy:** nome, punteggi e ID sono dati personali. Servono quindi informativa privacy, modulo "Sicurezza dei dati" e **cancellazione account sia nel gioco sia da una pagina web**, entrambe ospitate sul dominio del server.

### Obblighi

- **Consenso privacy (UMP / GDPR):** richiesto in Europa e Svizzera prima di mostrare pubblicità personalizzate.
- **Pubblico 13+** dichiarato nel questionario di Play Console, con la classificazione dei contenuti IARC.
- **Informativa privacy** pubblicata a un indirizzo web e modulo "Sicurezza dei dati" compilato, perché l'SDK delle pubblicità raccoglie l'ID pubblicitario e il server salva nome e punteggi.
- **Cancellazione account:** il gioco crea un account sul server, quindi Google Play richiede di poterlo cancellare sia dall'app sia da una pagina web.
- **Account sviluppatore personale nuovo** (creato a novembre 2026, in verifica): prima della produzione serve un test chiuso con almeno **12 tester per 14 giorni consecutivi**. Conviene avviarlo appena l'account è verificato, anche con la build attuale, perché la build si può aggiornare durante il test.

## Roadmap

**Fase 1 (fatta):** porting a GDScript, volo, effetti sonori, traffico (auto, furgoni, camion, bus, cabrio, auto lavate), abbaglianti di avviso, cambi di corsia con freccia, traffico sulla carreggiata opposta, portali, cavalcavia, gallerie, cantieri con corsia chiusa, cacca con mirino, boost, combo, passaggi a filo, volo radente, briciole, morte al primo colpo, HUD, touch, pausa, game over, record.

L'ordine segue le dipendenze. Il Continua viene prima perché è il cuore della monetizzazione e si prova su PC con una pubblicità finta. Le tratte vengono prima del meteo perché il meteo cambia all'uscita delle gallerie e per tratta. Il server arriva dopo le tratte, perché la classifica mostra anche fin dove si è arrivati, e prima delle pubblicità vere, perché il dominio ospita l'informativa privacy. L'economia viene prima delle pubblicità vere, che altrimenti non avrebbero niente da raddoppiare.

**Subito, in parallelo:** appena l'account Play Console è verificato, caricare la build attuale nel test interno e poi avviare il test chiuso con 12 tester, per far partire i 14 giorni.

### Fase 2: ciclo di partita e Continua (pubblicità finta)
- [x] Countdown 3-2-1 a inizio partita (suoni già pronti), riusato dopo il Continua
- [x] `AdService` + `MockAdService` (pubblicità simulata di 2 s, successo o annullamento)
- [x] Stato `CONTINUE_OFFER`: pannello "Continue?", anello di 5 s, pulsanti
- [x] Ripresa: pulizia degli ostacoli davanti, invulnerabilità con lampeggio, punteggio conservato, 1 per partita
- [x] Regole della pubblicità a schermo intero (contatore partite e intervallo minimo) con la versione finta
- [x] Salvataggio in JSON con versione (record, partite giocate, impostazioni) al posto del solo record

### Fase 3: tratte della A2
- [ ] Definizione dati delle tratte (nome, cantone, lunghezza, meteo possibili)
- [ ] Cartelli "Welcome to Canton …" e bonus di tratta
- [ ] Barra di avanzamento e mini mappa nell'HUD, "fin dove sei arrivato" nel game over
- [ ] Giro successivo dopo Basilea, a difficoltà più alta
- [ ] *Variante da valutare:* bivio di Bellinzona con la A13 del San Bernardino (Roveredo, Mesocco, Thusis, Coira)

### Fase 4: meteo e giorno/notte
- [ ] Preset d'ambiente (nebbia, sole, luce ambiente, cielo, luci) con transizioni graduali, riusando il sistema delle gallerie
- [ ] Sole, nuvoloso, tramonto, nebbia
- [ ] Notte: cielo scuro, anabbaglianti sempre accesi, lampioni
- [ ] Pioggia: poche particelle attorno alla camera, strada lucida, nuovi suoni (pioggia in loop, tuono)
- [ ] Moltiplicatore di punti nell'HUD ("Foggy ×1.2", "Night ×1.3")

### Fase 5: server dei giochi e classifica mondiale
- [ ] Nuova VPS Infomaniak (1 vCPU / 2 GB) + dominio dedicato ai giochi, sottodominio `api.`
- [ ] Docker Compose: Caddy (HTTPS), API, PostgreSQL 17, backup notturno verso kDrive, swap
- [ ] Monitoraggio: hub Beszel sulla VPS esistente, agent sul server dei giochi, avvisi su CPU, RAM, disco, server giù e `/health`
- [ ] Repository `game-services` separato: API ASP.NET Core + PostgreSQL + Dapper (giocatori, collegamento a Play Giochi, partite, classifiche sempre/settimana/giorno), migrazioni DbUp, test con Testcontainers
- [ ] Pipeline GitHub Actions: build, test, immagine Docker, trasferimento via SSH, migrazioni, `docker compose up`, controllo `/health` con ripristino automatico
- [ ] Controlli di plausibilità e limite di richieste
- [ ] Pagine web: informativa privacy e cancellazione account
- [ ] Nel gioco: account anonimo, nome modificabile, invio della partita al game over con coda offline
- [ ] Game over con posizione mondiale e "NEW WORLD RECORD!", schermata della classifica
- [ ] Plugin Play Games Services v2 per Godot: accesso automatico e collegamento dell'account
- [ ] Cancellazione account dalle impostazioni del gioco

### Fase 6: economia e progressione
- [ ] Briciole d'oro: raccoglibile raro + conversione della distanza a fine partita
- [ ] "Doppio bottino" con pubblicità a premio (finta)
- [ ] Negozio di skin del piccione (colori, cappellini)
- [ ] 3 missioni giornaliere, azzerate a mezzanotte (ora locale)
- [ ] *Da decidere:* secondo Continua con le briciole

### Fase 7: pubblicità vere (Android)
- [ ] Scelta del plugin AdMob e `AdMobAdService` in GDScript (i plugin espongono API GDScript: nessun ponte)
- [ ] Consenso UMP al primo avvio
- [ ] ID di prova, poi ID reali; caricamento anticipato; gestione degli errori senza bloccare il gioco
- [ ] Test sul S24 e su un telefono di fascia bassa
- **Da provare presto:** i plugin Java su Android (vale anche per Play Giochi), anche in parallelo con la Fase 3.

### Fase 8: acquisti in-app
- [ ] Plugin Google Play Billing
- [ ] "Rimuovi pubblicità" (acquisto una tantum) con ripristino degli acquisti
- [ ] *Eventuale:* pacchetti di briciole d'oro

### Fase 9: pubblicazione su Google Play
- [x] Account Play Console creato (in verifica)
- [ ] Test chiuso con 12 tester per 14 giorni, da avviare subito (vedi sopra)
- [ ] Firma dell'app, AAB, livello API richiesto
- [ ] Modulo "Sicurezza dei dati" (pubblicità + server), link alla cancellazione account, questionario IARC (13+)
- [ ] Scheda dello store: icona, screenshot, video breve
- [ ] Test interno → test chiuso (12 tester × 14 giorni) → produzione

### Fase 10: dopo il lancio
- Falco che insegue se vai troppo piano
- Polizia: se la colpisci parte il "livello ricercato" con un elicottero o un drone che ti insegue
- Autovelox con flash accecante, vento laterale
- Power-up: mega-cacca, magnete per le briciole, scudo di piume, slow-motion
- Musica
- Opzione controllo con inclinazione (accelerometro)
- iOS (Game Center per l'identità)
- Pipeline del gioco: export AAB headless e caricamento automatico nel test interno di Play Console
- Classifiche tra amici, classifica per tratta

## Idea: meteo e ora del giorno (Fase 4)

Condizioni che cambiano la **distanza visiva** e l'atmosfera:

| Condizione | Visibilità | Effetti |
|---|---|---|
| **Sole** | piena (com'è ora) | ombre nette, cielo azzurro |
| **Nebbia** | molto ridotta | nebbia fitta e grigia; i mezzi spuntano all'improvviso, fari e abbaglianti diventano l'avviso principale |
| **Pioggia** | ridotta | gocce attorno alla camera, strada bagnata e lucida con i riflessi dei fari, spruzzi dietro i camion, cielo coperto, lampi e tuoni ogni tanto |
| **Notte** | ridotta ai fari | sole spento, cielo scuro con stelle, lampioni accesi, anabbaglianti sempre accesi con cono di luce, fanalini rossi più visibili sull'altra carreggiata |

Si possono combinare, ad esempio notte con pioggia.

Note di design:
- Con meno visibilità servono più avvisi: abbaglianti, frecce e lampeggianti del cantiere sono già unlit e restano leggibili. Si potrebbero rendere più marcati quando la visibilità è bassa.
- Il varco garantito resta uguale. Si potrebbe compensare la visibilità ridotta allungando un po' la distanza tra le file o con un leggero bonus punti ("Foggy x1.2", "Night x1.3").
- Il cambio di meteo potrebbe avvenire all'uscita delle gallerie, che è il momento naturale per una transizione.
- Ogni condizione andrebbe definita come preset (densità e colore della nebbia, energia di sole e ambiente, colore del cielo, luci accese) con transizioni graduali, riusando il sistema che già scurisce le gallerie.
- Su mobile la pioggia va fatta con poche particelle legate alla camera, senza luci dinamiche.

## Audio

| Evento | Suono | Note |
|---|---|---|
| Mezzo che lampeggia (piccione sulla sua traiettoria) | `horn_car` / `horn_car_double`, `horn_truck` per camion e bus | 3D, segue il mezzo; max uno ogni 0.6 s |
| Mezzo che sfreccia accanto (< 5.5 m) | `passby_car` / `passby_truck` | parte 0.6 / 0.85 s prima del sorpasso, così il picco coincide |
| Cacca su un mezzo | `splat`, `combo` (tono crescente col moltiplicatore), clacson arrabbiato (70%) | il clacson arriva 0.35 s dopo, dal mezzo |
| Cacca sull'asfalto | `splat` piano e acuto | |
| Sgancio / munizioni finite | `poop_drop` / clic a vuoto | |
| Mirino agganciato | `lock_on` | solo quando cambia bersaglio |
| Briciole, passaggio a filo | `pickup`, `near_miss` | |
| Inizio salita | `flap` | |
| Freccia di un mezzo | `indicator_tick` / `indicator_tock` | 3D, si sente da lontano: avvisa del cambio corsia |
| Macchina operatrice nei cantieri | `works_beep` in loop | 3D, sulla prima macchina |
| Countdown 3-2-1, GO | `countdown_beep`, `countdown_go` | bus UI |
| Secondi dell'anello "Continue?" | `ui_click` più acuto | |
| Schianto, schermata di game over | `crash`, `game_over` | |
| Pulsanti, pausa | `ui_click` | bus UI, funziona anche in pausa |
| Loop | `road_loop`, `wind_loop`, `tunnel_loop` | volume (e tono del vento) in base a velocità, boost e buio della galleria |

I volumi si ritoccano in `game_audio.gd` (`BASE_DB` per effetto, `WORLD_BUS_DB`/`AMBIENCE_BUS_DB`/`UI_BUS_DB` per bus) e in `main.gd` (`_update_ambience`) per i loop. Per rigenerare i suoni: `python Tools/synth_sfx.py Audio/sfx`.
