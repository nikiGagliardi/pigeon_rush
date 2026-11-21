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
- la prima partita è normale (da Roveredo), la seconda è la sfida giornaliera;
- in ogni partita un Continua con la pubblicità finta, poi la fine e "Try again", che ricarica la scena;
- deve completare almeno 2 tratte per partita, con il cartello a bordo strada allineato al confine (entro 3 m);
- prima di partire, controlla le regole della pubblicità a schermo intero, l'anello delle tratte, i seed della sfida giornaliera, l'estrazione di meteo e ora (prima tratta sempre di giorno), i preset di atmosfera e il salvataggio JSON.

Termina con `[Smoke] OK` se non ci sono errori, altrimenti stampa gli errori ed esce con codice 1. Non tocca il record salvato.

```
godot --headless --path . --fixed-fps 60 -- --smoke-test
```

Opzioni (dopo `--`):
- `--shots`, con un driver video (non `--headless`): salva in `user://` una schermata ogni 6 s e una per ogni stato (countdown, impatto, "Continue?", pubblicità, game over);
- `--survive=20`: impatti ignorati solo per i primi 20 s, per partite più brevi;
- `--start=5`: la prima partita della prova parte dalla tratta indicata (0 = Roveredo, 5 = Lucerna → Zurigo…), per vedere paesaggi e luoghi tipici con `--shots`;
- `--no-ads`: simula la mancanza di pubblicità, quindi niente pannello "Continue?" (funziona anche giocando normalmente).
- `--time=night` e/o `--weather=fog`: forzano ora (`day`, `sunset`, `night`) e meteo (`sun`, `cloudy`, `fog`, `rain`, `snow`) di tutte le tratte, anche giocando normalmente.
- `--api=http://127.0.0.1:8099`: usa un server di prova invece di `api.moesagames.ch` (solo build di debug, anche giocando normalmente). Nella prova automatica il client online è spento se manca `--api`, così non tocca mai il server vero; con `--api` controlla anche che entrambe le partite ricevano ticket e risposta, che arrivi il saldo delle briciole d'oro e che una missione si possa riscuotere. Usa `user://online_smoke.json`, non l'account vero. Server finto: `python Tools/mock_api.py 8099` (rifiuta le partite senza le statistiche delle missioni).

**Provare meteo e ora mentre si gioca** (solo build di debug, cioè da editor): **F7** cambia l'ora del giorno, **F8** il meteo, **F9** torna a quelli del seed. Funziona anche nel menu e resta valido dopo "Try again". Il bonus di punti segue quello forzato.

## Comandi

| Azione | Tastiera | Gamepad | Touch |
|---|---|---|---|
| Volare | WASD / frecce | Stick sinistro / D-pad | Joystick flottante (metà sinistra) |
| Sganciare | Spazio / J | A / grilletto destro | Tocco sulla metà destra |
| Pausa | Esc / P | Start | Pulsante "II" |
| Indietro (Android) | — | — | Tasto indietro: in volo mette in pausa, in pausa riprende, chiude classifica e impostazioni, nel game over torna al menu, nel titolo chiede un secondo tocco per uscire |

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
- **Luci dei mezzi pesanti:** con i fari accesi (notte, galleria, pioggia, nebbia, neve) i camion mostrano una barra di luci arancioni sopra la cabina, due luci bianche agli angoli alti del rimorchio e le luci di ingombro lungo i fianchi; i bus il display della destinazione illuminato e due luci in alto. Al buio si distinguono subito dalle auto, che hanno solo i fari.
- **Abbaglianti:** se sei sulla traiettoria di un mezzo (stessa corsia, sotto il tetto) tra 15 e 85 m, ti lampeggia 2-3 volte. Lampeggia solo il primo mezzo della corsia: quelli dietro non ti vedono.
- **Cambi di corsia:** ogni tanto un mezzo mette la freccia (1.5 s) e si sposta nella corsia accanto. È raro (ogni 200-300 m all'inizio, 120-220 m a difficoltà massima) e leale: parte solo da mezzi a 3.5-5.5 s dal piccione, solo se nella corsia di destinazione c'è spazio, mai verso una corsia chiusa da un cantiere e mai se chiuderebbe il varco minimo garantito.
- **Gallerie (320-560 m):** soffitto a 5.6 m e ventilatori appesi, quindi niente volo alto. All'interno è buio: si vedono lampade, fari e abbaglianti. La camera si abbassa da sola prima del portale.
- **Lavori:** chiudono la corsia sinistra o destra per 160-240 m. Le due estremità sono speculari (cartello, carrello con freccia, coni e rete in diagonale): una verso il piccione e una verso le auto, che sono quelle a cui serve davvero la chiusura. Un ponteggio con rete arancione alto 8 m (più del volo massimo) impedisce di passarci sopra: la strada si stringe davvero a due corsie, con tutto il traffico lì. La rete è un muro morbido (ti spinge, non ti uccide) e segue la diagonale dei coni. I carrelli con la freccia sono invece ostacoli veri: se sei nella corsia chiusa, spostati prima.
- **Tratte:** si vola su un anello di 9 tratte (vedi "L'anello" più sotto). All'ingresso di ogni tratta c'è un **cartello verde a bordo strada** (oltre il guardrail esterno, solo scenografia) che si vede arrivare da lontano. Quando ci passi accanto compare anche il banner nell'HUD ("WELCOME TO TICINO", oppure il nome della zona) con un bonus di 500 × giro. In alto al centro ci sono il nome della tratta e la barra di avanzamento; il game over mostra fin dove si è arrivati ("Lap 1 · Leventina 62%").
- **Partenza:** le prime 3 partite normali partono da Roveredo (tratte corte, primo cartello presto); dopo, da una tratta a caso dell'anello, tranne la galleria del Gottardo. Il titolo la mostra sotto "PLAY" ("From Zurich → Walensee"); "Try again" ne estrae una nuova.
- **Giri:** ripassando dalla partenza inizia il giro successivo, con i punti distanza moltiplicati (×1.25 al secondo giro, ×1.5 al terzo…) e le file di traffico un po' più fitte.
- **Sfida giornaliera:** dal titolo, "DAILY CHALLENGE". Ogni giorno (UTC) ha un seed e una tratta di partenza uguali per tutti, quindi lo stesso percorso e lo stesso meteo. Il record del giorno è separato da quello normale.
- **Meteo e ora del giorno:** ogni tratta ha il suo meteo (sole, nuvoloso, nebbia, pioggia, neve, tra quelli possibili per quella tratta) e la sua ora (giorno 60%, tramonto 20%, notte 20%), estratti dal seed. La prima tratta della partita è sempre di giorno. Il cambio avviene all'ingresso della tratta: graduale in 5 s all'aperto, in 1 s se si è in galleria.
- **Bonus di visibilità:** i punti distanza si moltiplicano per notte ×1.3, nebbia ×1.2, neve ×1.15, pioggia ×1.1 (cumulabili: notte con nebbia ×1.56). Il bonus attivo è scritto in oro sotto la barra della tratta.
- **Suggerimenti delle prime partite:** compaiono sopra le munizioni nel momento in cui servono (comandi di volo, primo mirino, primo colpo, primo passaggio a filo, munizioni sotto 3, volo radente dopo 25 s), una volta sola ciascuno. "SHOW TIPS AGAIN" nelle impostazioni li fa ricomparire.
- **Impostazioni** (dal titolo e dalla pausa): volume, vibrazione, suggerimenti, informativa privacy, versione del gioco.
- **DEVELOPER** (nelle impostazioni, per tarare la difficoltà): metri a cui la difficoltà arriva al massimo, curva, difficoltà di partenza e moltiplicatore del traffico, con l'anteprima della curva e la riga "SHOW IN HUD" (difficoltà e traffico in tempo reale durante la partita). Sempre visibile nelle build di debug; in quelle di rilascio (test interno da Play) si sblocca toccando 7 volte la versione in fondo alle impostazioni. Valori salvati in `user://dev_tuning.json`; con valori diversi dai default le partite non chiedono il ticket, quindi restano fuori classifica (e non contano per briciole d'oro e missioni). La prova automatica usa sempre i default.
- **Briciole d'oro:** la valuta del gioco. Ogni tanto compare una **briciola d'oro** (più grande, alone chiaro, due anelli; la prima dopo 250 m, poi una ogni 300-600 m) che vale +50 punti e 5 briciole d'oro. A fine partita il server accredita 1 briciola ogni 100 m più 5 per ogni briciola d'oro raccolta, al massimo 200 a partita e 1500 al giorno, e solo per le partite iniziate online. Il game over mostra "+33 GOLDEN CRUMBS  •  total 1,250", il titolo il saldo. Si spendono nel negozio.
- **Negozio** (titolo → SHOP): cinque schede (BIRD, FEATHERS, HEAD, FACE, NECK) che si combinano liberamente. Il piccione in 3D a sinistra prova ogni oggetto prima di comprarlo; EQUIP lo indossa, BUY lo compra e lo indossa subito.
  - Fase 1: corvo (speciale); piumaggi Colomba, Notte, Svizzero (croce bianca sulle ali), Arcobaleno (collo e coda), Oro; cappelli Berretto, Tirolese, Cowboy, Casco da corsa, Corona; Occhiali da sole, Occhialoni da aviatore alzati sulla fronte; Sciarpa rossa, Campanaccio.
  - Prezzi e oggetti in vendita li decide il server (cambiabili senza aggiornare l'app); comprare richiede la rete, indossare quello che hai funziona anche offline.
  - Cambia solo l'aspetto: hitbox, mira e punto da cui cade la cacca restano quelli del piccione.
- **Missioni giornaliere:** dal titolo, "MISSIONS". Tre obiettivi al giorno uguali per tutti (per esempio "Splat 4 buses", "Fly 1500 m at night", "Fly today's challenge"), nuovi a mezzanotte UTC. Contano le partite iniziate online; il progresso lo calcola il server. Una missione completa si riscuote con "CLAIM" (30-90 briciole d'oro). Il pulsante del titolo mostra quante ce ne sono da riscuotere ("MISSIONS (1)") e il game over avvisa quando una partita ne completa una.
- **Classifica mondiale:** nel game over la posizione ("WORLD #1,234  •  THIS WEEK #56"); "NEW WORLD RECORD!" quando la partita porta in testa alla classifica di sempre, "#1 IN TODAY'S CHALLENGE!" in quella del giorno.
- **Difficoltà:** cresce con i metri percorsi, non col tempo: in fretta all'inizio, poi più piano, fino al massimo verso la fine del primo giro (14% a 1 km, 57% all'ingresso nel Mittelland, 100% a 12 km). Il traffico più fitto del primo giro è nella discesa del San Bernardino. Dal secondo giro c'è in più il traffico extra dei giri. La velocità base sale da 16 a 30 m/s. Ogni tratta ha il suo profilo: traffico più o meno fitto, più o meno camion, più gallerie o più cantieri.

## Architettura

Tutta la scena viene costruita **da codice** (`Scenes/Main.tscn` contiene solo il nodo radice): niente `.tscn` o `.tres` da mantenere a mano. Mesh low-poly generati proceduralmente con vertex color (1 materiale = poche draw call su mobile).

```
Scripts/
├── main.gd                  Regista: costruzione scena, stati di gioco (countdown, Continua), ordine di update, prova automatica
├── Core/
│   ├── game_config.gd       Tutte le costanti di bilanciamento
│   ├── dev_tuning.gd        Curva della difficoltà e traffico, regolabili dal pannello DEVELOPER
│   ├── game_session.gd      Stato partita (munizioni, tempo, difficoltà, game over)
│   ├── speed_controller.gd  Velocità base + boost cumulabili
│   ├── score_service.gd     Punteggio, combo, statistiche
│   ├── cells.gd             Griglia 3 corsie × 3 fasce (bitmask) per il varco garantito
│   ├── node_pool.gd         Pool generico di nodi
│   ├── actions.gd           Input map registrata via codice
│   ├── save_data.gd         Salvataggio JSON con versione (record, partite giocate, impostazioni, suggerimenti visti)
│   └── tutorial_hints.gd    Suggerimenti delle prime partite, uno per tipo
├── Ads/
│   ├── ad_service.gd        Contratto delle pubblicità (a premio e a schermo intero)
│   ├── mock_ad_service.gd   Pubblicità finta da 2 s per PC e prove (si può saltare)
│   ├── interstitial_policy.gd  Quando mostrare quella a schermo intero
│   └── ads.gd               Accesso statico: il servizio vive fuori dalla scena e sopravvive a "Try again"
├── Online/
│   └── game_services_client.gd  Server dei giochi: account anonimo, ticket di partita, invio con coda offline,
│                                classifiche, nome, cancellazione, saldo delle briciole d'oro, missioni
│                                (vive fuori dalla scena, come Ads)
├── Route/
│   ├── route_segment.gd     Una tratta: nome, cantone, lunghezza, profilo di traffico e strutture, gallerie, meteo possibili
│   ├── route_data.gd        Le 9 tratte dell'anello
│   ├── route_tracker.gd     Tratta attuale, avanzamento, giro, seed derivati per tratta
│   ├── track_conditions.gd  Meteo e ora del giorno di una tratta (dal seed) e bonus di punti
│   └── run_setup.gd         Partita normale (seed e partenza casuali, le prime 3 da Roveredo) o sfida giornaliera (seed della data)
├── Rendering/
│   ├── low_poly_builder.gd  Primitive → ArrayMesh flat-shaded con vertex color
│   ├── asset_warmup.gd      Pre-costruzione mesh e pre-compilazione shader durante il menu
│   └── palette.gd           Colori e materiali condivisi
├── Player/
│   ├── pigeon_controller.gd Movimento X/Y con inerzia, inclinazione, caduta finale
│   ├── pigeon_model.gd      Uccello procedurale con ali animate: specie e piumaggio da BirdLook, agganci per gli accessori
│   ├── bird_catalog.gd      Specie, piumaggi e accessori disegnabili (id del negozio)
│   ├── bird_look.gd         Cosa indossa il piccione (salvato), controllato contro gli oggetti posseduti
│   ├── bird_accessories.gd  Cappelli, occhiali, sciarpa, campanaccio, costruiti attorno al loro aggancio
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
│   ├── route_sign.gd        Cartello verde di ingresso tratta a bordo strada (solo scenografia)
│   ├── tunnel.gd / tunnel_meshes.gd          Gallerie a doppia canna (buio, soffitto, ventilatori)
│   ├── road_works.gd / road_works_meshes.gd  Cantieri con corsia chiusa e macchinari
│   ├── pickup.gd            Briciole (ricarica cacca) e briciole d'oro
│   ├── road_scroller.gd / road_meshes.gd     Strada a segmenti riciclati, con il paesaggio della zona
│   ├── landscape_meshes.gd  Paesaggi a bordo strada (Ticino, Riviera, Alpi, Altopiano, Lago, Cittadina, Città)
│   ├── landmark_meshes.gd / landmark_spawner.gd  Luoghi tipici, uno per tratta
│   ├── structure_meshes.gd
│   ├── atmosphere.gd        Preset di meteo × ora del giorno e transizioni (cielo, sole, nebbia, luce, montagne, strada bagnata, fari)
│   └── scenery_factory.gd   Cielo, sole, nebbia, montagne
├── Audio/game_audio.gd      Pool di player 2D/3D, loop d'ambiente, bus World/Ambience/UI, riverbero in galleria
├── CameraRig/chase_camera.gd Inseguimento, FOV dinamico, shake
├── Effects/                 Testi fluttuanti, esplosione di piume, pioggia e neve attorno alla camera
└── UI/                      HUD (con i suggerimenti), controlli touch, schermate (titolo, pausa, "Continue?", game over, countdown),
                             classifica mondiale, missioni giornaliere, negozio con anteprima 3D, impostazioni (e DEVELOPER)
```

Convenzioni GDScript: file in `snake_case`, `class_name` in `PascalCase`, costanti in `MAIUSCOLO`, eventi come **segnali** (`pigeon_hit`, `vehicle_warned`…), cache statiche con `static var`.

### Scelte chiave

- **Mondo "tapis roulant":** il piccione resta a Z = 0. Strada e strutture scorrono alla velocità del piccione, i mezzi a velocità piccione + traffico. Niente problemi di precisione dei float e il boost è solo un moltiplicatore.
- **Varco garantito:** ogni fila lascia almeno 2 celle libere su 9, e almeno una è adiacente a una cella libera della fila precedente. Le strutture (portali, cavalcavia) che arrivano nello stesso istante vengono incluse nel calcolo.
- **Collisioni manuali AABB** con sweep sull'asse Z: deterministiche, economiche, nessun "salto" dell'ostacolo ad alta velocità.
- **Guida a destra:** i mezzi contromano (verso +Z) hanno lo spartitraffico alla loro sinistra, quindi la carreggiata opposta sta sul lato +X. Lì il traffico va nella stessa direzione del piccione: a inizio partita ti sorpassa, quando acceleri sei tu a superarlo.
- **Strutture lunghe** (gallerie, cantieri): nel calcolo del varco conta l'intervallo [fronte, coda], non un singolo istante. Un mezzo non viene generato nella corsia chiusa se raggiungerebbe il cantiere prima di uscire dalla visuale.
- **Niente scatti alla prima comparsa:** tutti i mesh procedurali (gallerie, cantieri, veicoli…) vengono costruiti durante il menu, uno per frame, e disegnati una volta in miniatura dietro al pannello del titolo, così geometria e shader sono già pronti quando parte la partita. In più l'export Android ha lo **Shader Baker** attivo.
- **Icona disegnata in SVG:** i livelli sono in `Art/Icon` (sfondo, piccione, sagoma monocromatica, icona completa). `godot --headless --path . --script res://Tools/render_icons.gd` rigenera i PNG usati dall'export Android (icona adattiva 432 px, classica 192 px) e da Play Console (512 px).
- **Audio sintetizzato:** tutti gli effetti (`Audio/sfx/*.wav`, 44.1 kHz mono) sono generati da `Tools/synth_sfx.py` (numpy/scipy), niente asset esterni. I passaggi dei mezzi hanno il Doppler già nel file, quindi il Doppler di Godot è spento; i loop (strada, vento, galleria) sono senza cucitura e vengono messi in loop a runtime.
- **Mesh veloci anche in GDScript:** `LowPolyBuilder` tiene in cache le forme unitarie già espanse in triangoli con la normale di faccia, e le trasforma con `Transform3D * PackedVector3Array` (codice nativo, nessun ciclo per vertice). I 60 mesh del gioco si costruiscono in circa 30 ms.
- **Ordine di update esplicito** in `main.gd` (`_tick_playing`): niente dipendenze dall'ordine dei `_process`.
- **Percorso da seed:** ogni partita ha un seed. Il traffico usa flussi casuali separati (strutture, file, briciole, cambi di corsia), ri-seminati all'inizio di ogni tratta a partire da seed, tratta e giro, e la difficoltà dipende dai metri e non dal tempo. Con lo stesso seed le strutture sono identiche alla stessa distanza e il traffico è quasi identico (può cambiare un po' quando una struttura arriva in un momento diverso, perché dipende dalla velocità). Il meteo di ogni tratta viene dallo stesso seed.

## Struttura di gioco e monetizzazione

### Decisioni prese

- **Solo mobile:** Android prima, iOS in un secondo momento. Tastiera e gamepad restano solo per sviluppare e provare su PC, senza versione PC pubblicata.
- **Pubblico 13+:** niente programma Famiglie di Google Play. Grafica e testi restano coerenti con un pubblico di adolescenti e adulti.
- **Volo continuo su un anello di tratte**, senza livelli: Roveredo → Bellinzona → Gottardo → Lucerna → Zurigo → Walensee → Coira → San Bernardino → Roveredo, poi si ricomincia. Il record si batte in un'unica corsa, e le tratte danno il senso di progresso.
- **Partita normale da una tratta a caso** (le prime 3 da Roveredo): con partite da 2-4 km, partendo sempre da Roveredo Zurigo, il Walensee e il San Bernardino non li vedeva quasi nessuno. I record restano confrontabili perché la difficoltà dipende dai metri percorsi, non dalla tratta (che cambia solo un po' il traffico). La **sfida giornaliera** ha una tratta di partenza uguale per tutti.
- **Gallerie a doppia canna e 3 corsie** ovunque, anche al Gottardo e al San Bernardino.
- **Meteo e ora del giorno casuali per tratta**, non fissi: vengono dal seed della partita, quindi cambiano da una partita all'altra ma nella sfida giornaliera sono uguali per tutti. La prima tratta della partita è sempre di giorno.
- **Un solo "Continua" con pubblicità a premio per partita.**
- **Server proprio su Infomaniak:** una nuova VPS dedicata ai giochi (1 vCPU / 2 GB per iniziare, da scalare quando il monitoraggio lo indica) con un dominio dedicato (`moesagames.ch`), condivisa da tutti i giochi. Ospita API, classifica mondiale, informativa privacy e pagina di cancellazione account. Tutto gira in **Docker Compose**.

### Perché il volo continuo e non i livelli

| | Livelli | Volo continuo a tratte (scelto) |
|---|---|---|
| Lavoro | Livelli da disegnare e bilanciare uno per uno | La generazione procedurale c'è già |
| Morte al primo colpo | Frustrante: si ripete il livello | Naturale: "batti il tuo record" |
| "Continua" con pubblicità | Ha poco senso (tanto vale ricominciare il livello) | Ha senso: il giocatore sta perdendo un record |
| Spazi per la pubblicità | Pochi (tra i livelli) | A ogni morte |
| Meteo e giorno/notte | Fissi per livello | Cambiano durante il volo, a ogni tratta |

### L'anello

Un anello vero di circa 400 km, accorciato circa 1:30 (13,2 km nel gioco): A13 Roveredo → Bellinzona, A2 fino a Lucerna, A14/A4 fino a Zurigo, A3 lungo il lago di Zurigo e il Walensee fino a Coira, poi di nuovo A13 per il San Bernardino fino a Roveredo. Una partita normale fa 1,5-2 km, una buona 4 km: per questo le prime tratte sono corte e il primo cartello arriva presto. Un giro completo richiede 7-8 minuti senza errori.

| # | Tratta | Si entra in | Metri | Traffico | Strutture più frequenti | Meteo possibili |
|---|---|---|---|---|---|---|
| 1 | Roveredo → Bellinzona | Graubünden | 800 | leggero, pochi camion | portali, cavalcavia | sole, nuvoloso, pioggia |
| 2 | Bellinzona → Biasca | Ticino | 1100 | normale | portali, cantieri | sole, nuvoloso, pioggia |
| 3 | Biasca → Airolo (Leventina) | | 1400 | normale, più camion | gallerie | sole, nuvoloso, nebbia, pioggia |
| 4 | Galleria del Gottardo | | 900 | camion | quasi solo gallerie | (dentro la galleria) |
| 5 | Göschenen → Lucerna | Uri | 1800 | normale | gallerie, portali | pioggia, nebbia, nuvoloso, sole |
| 6 | Lucerna → Zurigo | Lucerne | 1800 | **fitto** | **cantieri**, cavalcavia | nebbia, nuvoloso, sole, pioggia |
| 7 | Zurigo → Walensee | Zurich | 2000 | fitto | gallerie sul lago | nuvoloso, pioggia, sole, nebbia |
| 8 | Sargans → Thusis | Graubünden | 1600 | normale | portali | sole, nuvoloso, pioggia, neve |
| 9 | San Bernardino → Roveredo | | 1800 | camion | gallerie | neve, sole, nebbia, nuvoloso |

I valori sono in `Scripts/Route/route_data.gd` e si bilanciano lì.

- Il cartello all'ingresso (a bordo strada e nel banner) dice "WELCOME TO …" quando si cambia cantone, altrimenti il nome della zona ("LEVENTINA"), e "LAP 2" ripassando dalla partenza. Sotto c'è il nome della tratta.
- Il cartello a bordo strada parte dalla linea di generazione (300 m) e scorre con la strada, quindi arriva accanto al piccione esattamente al cambio di tratta. Gallerie e cantieri non attraversano mai il confine (diventano portali, sempre in base al seed), e nei pressi del cartello non ci sono portali né cavalcavia: il cartello non finisce mai dentro la montagna o sotto un ponte.
- Le gallerie hanno il nome della tratta sul portale (Gotthard Tunnel, Seelisberg Tunnel, Kerenzerberg Tunnel, San Bernardino Tunnel…).
- Ci sono **missioni giornaliere** ("colpisci 5 bus", "vola 1 km di notte"), che portano il giocatore a fare più partite (Fase 6).

### Ambientazioni per luogo

Ogni tratta si riconosce anche senza leggere il cartello. Idee per tratta (in grassetto i luoghi tipici; quelli fatti sono elencati sotto la tabella):

| Tratta | Paesaggio | Elementi riconoscibili | Note |
|---|---|---|---|
| Roveredo → Bellinzona | Valle stretta e verde, boschi di castagni, case in pietra, il fiume Moesa | Ingresso a Bellinzona con i **castelli** (Castelgrande) sulla collina | Tratta d'apertura: luminosa e tranquilla |
| Bellinzona → Biasca | Piana larga della Riviera, montagne ripide ai lati, vigneti | Cave di granito, ferrovia accanto all'autostrada | Primi camion sul serio |
| Leventina | Valle che si stringe, gole, rocce scure, cascate | **Viadotti** della Biaschina, chiese con campanile, Airolo ai piedi del passo | Molte gallerie corte |
| Galleria del Gottardo | Solo galleria: luci gialle, ventilatori, nicchie di sicurezza | Cartelli con i chilometri ("km 8 / 17"), portale nord di Göschenen | Tratta "di respiro", buia; all'uscita cambia il meteo (favonio) |
| Göschenen → Lucerna | Valle della Reuss, poi il **lago dei Quattro Cantoni** (Urnersee) con montagne a picco sull'acqua | Chiesa di Wassen, Altdorf, Pilatus all'arrivo, il Ponte della Cappella di Lucerna in lontananza | Primo lago: grande piano d'acqua con riflessi |
| Lucerna → Zurigo | Altopiano: colline, campi, fattorie, boschi, lago di Zugo | Capannoni, centri commerciali, svincoli, **skyline di Zurigo** (Prime Tower) | Più traffico e cantieri: la tratta "urbana" |
| Zurigo → Walensee | Lago di Zurigo, poi il **Walensee** stretto tra pareti di roccia | Pareti dei Churfirsten a strapiombo, gallerie lungo la riva | Nebbia e pioggia frequenti |
| Sargans → Thusis | Valle del Reno larga, vigneti della Bündner Herrschaft, poi si stringe | Castello di Sargans, Coira con la città vecchia | Si torna verso le montagne |
| San Bernardino → Roveredo | Gola della **Via Mala**, alta montagna con neve, poi la discesa nella Mesolcina | Hinterrhein, **castello di Mesocco**, il ritorno a Roveredo | Gran finale del giro: neve possibile, poi la valle verde di partenza |

Come è fatto:
- **Paesaggi** (`LandscapeMeshes`): 7 tipi, ognuno con 4 varianti di segmento di strada da 40 m, così non si vedono ripetizioni. Sono nello stesso mesh della strada: nessuna draw call in più.
  - **Ticino:** castagni, rustici in pietra, muretti a secco, chiese con campanile;
  - **Riviera:** vigneti con il muretto, case in pietra, la ferrovia con la linea aerea accanto all'autostrada;
  - **Alpi:** abeti, rocce, chalet con il balcone e i gerani, fienili, mucche (bruna alpina, pezzata rossa, Holstein) con il campanaccio;
  - **Altopiano:** campi coltivati di vari colori, fattorie con il tetto grande e il silo, filari di alberi da frutto, mucche, capannoni;
  - **Lago:** riva in pietra e acqua oltre la carreggiata opposta, barche a vela, pontili, chalet e case sulla riva;
  - **Cittadina:** case colorate con le persiane, chiese;
  - **Città:** condomini, torri di uffici, capannoni con il colore dell'azienda, barriere antirumore.
- **Sequenza per tratta** (`RouteSegment.with_landscape`): per esempio Lucerna → Zurigo è cittadina, poi altopiano, poi città. I segmenti che ricompaiono in fondo prendono il paesaggio del punto in cui riappariranno (circa 350 m avanti), così all'arrivo del cartello il paesaggio è già quello nuovo.
- **Luoghi tipici** (`LandmarkMeshes`), uno per tratta a un punto fisso, compaiono in fondo nella nebbia e scorrono con la strada:
  - Bellinzona: Castelgrande sulla collina con la Torre Bianca, la Torre Nera e la Murata;
  - Leventina: chiesa bianca con il campanile alto, cipressi, parete di roccia;
  - Lucerna: Ponte della Cappella coperto, con i fiori, la Torre dell'acqua e la riva della città;
  - Zurigo: Prime Tower, Grossmünster con le due torri, guglia verde del Fraumünster;
  - Walensee: i sette Churfirsten oltre il lago;
  - Sargans: castello bianco sulla rupe con la bandiera svizzera;
  - Mesocco: rovine del castello e il campanile di Santa Maria del Castello.
- Da fare: il Gottardo (cartelli dei chilometri in galleria), Pilatus, montagne più basse nell'altopiano, finestre accese di notte in città.

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
| Tecnica | Saldo sul server (registro dei movimenti), verificato a ogni guadagno e spesa | Google Play Billing con un acquisto consumabile a ogni morte |
| Ricavi | Indiretti: il giocatore guarda più pubblicità "doppio bottino" e forse compra pacchetti di briciole | Diretti ma rari |

Proposta: il secondo Continua costa per esempio 150 briciole e c'è un massimo di 2 Continua per partita (1 con pubblicità + 1 con briciole). Il prezzo va bilanciato con quanto si guadagna in una partita media. I soldi veri entrano solo da **"Rimuovi pubblicità"** (acquisto una tantum) e, in seguito, eventualmente da **pacchetti di briciole**. *Da decidere più avanti, con l'economia già in funzione.*

**Anti-trucchi sulla valuta** (dettagli in `game-services/docs/difesa-briciole.md`). Un saldo salvato solo sul telefono si modifica in un attimo, e il 2° Continua con le briciole influisce sulla classifica. Per questo:
- **il saldo esiste solo sul server.** Il gioco non dice mai "aggiungi briciole": riferisce cosa è successo (partita, missione, pubblicità, acquisto), e il server verifica e calcola l'importo. In locale resta solo una copia per l'interfaccia;
- **ogni fonte è verificata:**
  - distanza e raccoglibili solo da partite con ticket valido e non sospette, con un tetto per partita;
  - missioni controllate sulle partite salvate;
  - doppio bottino e Continua con pubblicità tramite **AdMob Server-Side Verification** (callback firmata da Google, con il `runId` in `custom_data`);
  - pacchetti a pagamento verificati con la **Google Play Developer API**, con storno dei rimborsi;
- **le spese** (skin, 2° Continua) passano da endpoint del server atomici e idempotenti. Il saldo non può andare sotto zero, e la stessa fonte non paga mai due volte;
- **il 2° Continua è legato al ticket della partita.** I Continua dichiarati nella partita devono coincidere con quelli registrati, altrimenti la partita è sospetta;
- **tetti** per partita e al giorno, limite di richieste, controllo delle anomalie e Play Integrity prima dell'uscita pubblica;
- **offline:** le briciole restano "in attesa" fino alla sincronizzazione. Negozio e 2° Continua con le briciole funzionano solo online.

Effetto collaterale utile: con l'account collegato a Play Giochi il saldo e le skin sopravvivono a una reinstallazione.

### Classifica mondiale e identità del giocatore

**Obiettivo:** a ogni morte la partita viene inviata al server. Il game over mostra la posizione nel mondo ("#1234 in the world", "NEW WORLD RECORD!") e si può aprire la classifica.

**Come si riconosce il giocatore, senza registrazione.** Si combinano due sistemi:

| | Account anonimo del gioco | Google Play Games Services v2 (facoltativo) |
|---|---|---|
| Cos'è | Al primo avvio il server crea un giocatore e restituisce un ID e un token segreto, salvati sul telefono | Accesso automatico all'avvio, senza schermate: dà un ID giocatore Google e il nome del profilo Play Giochi |
| Pro | Funziona sempre, anche senza Play Giochi e su iOS | Il giocatore ritrova l'account dopo una reinstallazione o su un telefono nuovo; l'identità è verificabile dal server |
| Contro | Se l'app viene disinstallata l'account si perde | Non tutti usano Play Giochi; su iOS serve Game Center a parte |

**Flusso:**
1. Primo avvio: il gioco crea l'account anonimo. Il nome di default è casuale (`SwiftPigeon#0042`; con Play Giochi diventerà quello del profilo) e si cambia dalla schermata della classifica.
2. Se Play Giochi è attivo, il gioco chiede un codice monouso (`requestServerSideAccess`) e lo invia al server. Il server lo scambia con Google, verifica l'ID del giocatore con le API di Play Games e lo **collega** all'account. Con un telefono nuovo, lo stesso ID ritrova il vecchio account.
3. Nome visibile in classifica: sempre con il suffisso `#1234`, così due giocatori possono chiamarsi uguale. Il filtro delle parolacce è ancora da fare (per ora si interviene a mano).

**Server (stesso stack degli altri progetti):** ASP.NET Core (.NET 10) minimal API + **PostgreSQL** + Dapper, con HTTPS, sul server Infomaniak. È unico per tutti i giochi: ogni gioco ha il suo identificativo.

| Endpoint | Cosa fa |
|---|---|
| `POST /v1/players` | Crea l'account anonimo e restituisce ID, token e nome |
| `GET` / `PATCH /v1/players/me` | Profilo / cambio del nome |
| `DELETE /v1/players/me` | Cancella account, partite e record (richiesto da Google Play) |
| `POST /v1/games/{game}/runs/start` | Ticket di inizio partita (modalità, seed, data della giornaliera, versione), chiesto durante il countdown |
| `POST /v1/games/{game}/runs` | Invia una partita (ticket, punti, distanza, durata, colpi, combo, continue, giro, tratte, versione) e restituisce posizione mondiale, della settimana o del giorno e record personale |
| `GET /v1/games/{game}/leaderboards/{all\|week\|daily}` | Classifica: primi 50 (fino a 100) + la propria posizione |
| `POST /v1/players/me/google` | *Da fare:* collega Play Giochi (codice monouso) |

Protocollo completo in `game-services/docs/api.md`. Il seed della sfida giornaliera lo calcola il gioco dalla data; il server verifica che sia quello giusto (`PigeonRushRules.DailySeed`).

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
- **Mai bloccare il gioco:** il ticket si chiede durante il countdown (timeout 4 s), l'invio parte al game over mostrando "Sending to the world leaderboard…" e poi la posizione. Senza rete la partita resta nella coda locale (`user://online.json`, massimo 20) e riparte al prossimo avvio, alla fine della partita successiva o aprendo la classifica; il game over dice "Offline: your score will be sent later". Senza ticket la partita conta solo per il record personale. "Try again" funziona sempre.
- **Anti-trucchi:**
  - ticket di partita: la durata dichiarata non può superare il tempo passato sull'orologio del server;
  - controlli di plausibilità sul server: punti compatibili con distanza, colpi e passaggi a filo (`PigeonRushRules`, da aggiornare se cambia il calcolo dei punti), distanza compatibile con la durata e la velocità massima, versione minima;
  - limite di richieste;
  - le partite sospette vengono salvate ma non entrano in classifica, e la risposta sembra normale (shadow ban);
  - le briciole d'oro hanno il saldo sul server, con le verifiche descritte sopra (`game-services/docs/difesa-briciole.md`).
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

### Fase 3: tratte dell'anello
- [x] Dati delle 9 tratte (nome, cantone, lunghezza, profilo di traffico e strutture, gallerie, meteo possibili)
- [x] Anello Roveredo → … → Roveredo con giri successivi (moltiplicatore dei punti, traffico più fitto)
- [x] Seed della partita, flussi casuali separati e ri-seminati per tratta, difficoltà legata alla distanza
- [x] Sfida giornaliera: stesso seed e stessa tratta di partenza per tutti, record del giorno separato (salvataggio v2)
- [x] Cartello "Welcome to …" con bonus di tratta, barra di avanzamento nell'HUD, "Reached" nel game over
- [x] Cartello verde 3D a bordo strada all'ingresso di ogni tratta (oltre al banner)
- [ ] *Più avanti, con le ambientazioni:* portale con le destinazioni della tratta qualche centinaio di metri prima ("Biasca", "Airolo", "Luzern")
- [ ] Ambientazioni per luogo (vedi "Ambientazioni per luogo"): preset di paesaggio, laghi, città, elementi riconoscibili
- [ ] Mini mappa dell'anello nel game over

### Fase 4: meteo e giorno/notte
- [x] Meteo e ora del giorno per tratta dal seed (`TrackConditions`), prima tratta sempre di giorno
- [x] Preset di atmosfera (cielo, sole, ombre, luce ambiente, nebbia, montagne) per 5 meteo × 3 ore, con transizioni graduali sommate al buio delle gallerie
- [x] Sole, nuvoloso, nebbia, pioggia, neve; giorno, tramonto (sole basso davanti), notte (luna, cielo scuro)
- [x] Anabbaglianti accesi su tutti i mezzi di notte, con nebbia, pioggia, neve e in galleria
- [x] Pioggia e neve attorno alla camera senza particelle; strada (e mezzi) lucidi sotto la pioggia; loop di pioggia e tuoni sintetizzati
- [x] Moltiplicatore di punti nell'HUD ("NIGHT ×1.3  ·  FOG ×1.2")
- [x] Lampioni accesi di notte (e appena al tramonto): alone sulle lampade e macchie di luce sull'asfalto, additivi, spenti in galleria
- [ ] *Più avanti:* stelle, spruzzi dietro i camion, lampi col tuono, neve a terra

### Fase 5: server dei giochi e classifica mondiale
- [ ] Nuova VPS Infomaniak (1 vCPU / 2 GB) + dominio dedicato ai giochi (`moesagames.ch`), sottodominio `api.`
- [ ] Docker Compose: Caddy (HTTPS), API, PostgreSQL 17, backup notturno verso kDrive, swap
- [ ] Monitoraggio: hub Beszel sulla VPS esistente, agent sul server dei giochi, avvisi su CPU, RAM, disco, server giù e `/health`
- [ ] Repository `game-services` separato: API ASP.NET Core + PostgreSQL + Dapper (giocatori, collegamento a Play Giochi, partite, classifiche sempre/settimana/giorno), migrazioni DbUp, test con Testcontainers
- [ ] Pipeline GitHub Actions: build, test, immagine Docker, trasferimento via SSH, migrazioni, `docker compose up`, controllo `/health` con ripristino automatico
- [x] API `/v1`: giocatori anonimi con token, ticket `runs/start`, invio delle partite, classifiche sempre/settimana/giorno, cancellazione (migrazione `0002`, test xUnit + Testcontainers)
- [x] Controlli di plausibilità (ticket con l'orologio del server, velocità, durata, modello del punteggio di Pigeon Rush), shadow ban, ban e `--rebuild-leaderboards`, limite di richieste
- [x] Pagine web: informativa privacy (`/privacy`) e cancellazione account (`/delete-account`)
- [x] Nel gioco: account anonimo, ticket durante il countdown, invio della partita al game over con coda offline (`user://online.json`)
- [x] Game over con posizione mondiale ("WORLD #1,234 • THIS WEEK #56", "TODAY'S CHALLENGE: #12") e schermata della classifica (sempre, settimana, sfida di oggi)
- [x] Nome modificabile e cancellazione dei dati online dalla schermata della classifica
- [x] "NEW WORLD RECORD!" quando si è primi
- [ ] Filtro delle parolacce sui nomi
- [ ] Plugin Play Games Services v2 per Godot: accesso automatico e collegamento dell'account

### Fase 6: economia e progressione
- [x] Server: migrazione `0003_wallet` (saldo, registro dei movimenti) e servizio del portafoglio atomico e idempotente
- [x] Server: regole di guadagno e tetti per gioco (1 ogni 100 m, 5 per briciola d'oro, 200 a partita, 1500 al giorno)
- [x] Briciole d'oro: raccoglibile raro + conversione della distanza a fine partita, calcolate dal server sulle partite con ticket
- [x] Nel gioco: saldo solo come copia del server (titolo, game over, missioni); le partite offline valgono 0
- [x] 3 missioni giornaliere, nuove a mezzanotte UTC, verificate e riscosse sul server
- [x] Statistiche per le missioni nell'invio della partita (`busHits`, `truckHits`, `nightDistance`, `goldenCrumbs`) con controlli di coerenza sul server
- [x] Negozio (fase 1): corvo, piumaggi e accessori per testa, faccia e collo, con agganci uguali per tutte le specie; catalogo e acquisti sul server
- [ ] Negozio (fase 2): scia, splat, altri uccelli (gallina, aquila compatta, gabbiano, gufo)
- [ ] Scelta della tratta di partenza (sbloccata raggiungendola, pagata con le briciole)
- [ ] Cambio di una missione del giorno con le briciole
- [ ] "Doppio bottino" con pubblicità a premio (Fase 7, con la verifica SSV)
- [ ] *Da decidere:* secondo Continua con le briciole, legato al ticket della partita

### Fase 7: pubblicità vere (Android)
- [ ] Scelta del plugin AdMob e `AdMobAdService` in GDScript (i plugin espongono API GDScript: nessun ponte)
- [ ] Consenso UMP al primo avvio
- [ ] ID di prova, poi ID reali; caricamento anticipato; gestione degli errori senza bloccare il gioco
- [ ] AdMob Server-Side Verification: callback sul server per doppio bottino e Continua, con `runId` in `custom_data`
- [ ] Test sul S24 e su un telefono di fascia bassa
- **Da provare presto:** i plugin Java su Android (vale anche per Play Giochi), anche in parallelo con la Fase 3.

### Fase 8: acquisti in-app
- [ ] Plugin Google Play Billing
- [ ] "Rimuovi pubblicità" (acquisto una tantum) con ripristino degli acquisti
- [ ] *Eventuale:* pacchetti di briciole d'oro, verificati dal server con la Play Developer API, consumati dopo l'accredito, con storno dei rimborsi (Voided Purchases API)

### Fase 9: pubblicazione su Google Play
- [x] Account Play Console creato e verificato, primo AAB nel test interno
- [ ] Test chiuso con 12 tester per 14 giorni, da avviare subito (vedi sopra)
- [x] Firma dell'app (chiave di upload + Play App Signing), AAB con build Gradle, API 36, pacchetto `ch.moesagames.pigeonrush`
- [ ] Play Integrity su invio delle partite e acquisti (gioco + verifica sul server)
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

## Meteo e ora del giorno

| Condizione | Visibilità | Effetti |
|---|---|---|
| **Sole** | piena | ombre nette, cielo azzurro |
| **Nuvoloso** | quasi piena | cielo grigio, sole debole e nascosto, ombre leggere |
| **Nebbia** | molto ridotta (da 12 m, tutto coperto a 130 m) | cielo e montagne spariscono nel grigio; fari accesi |
| **Pioggia** | ridotta (da 70 m a 270 m) | trattini di pioggia attorno alla camera, strada un po' lucida, cielo scuro, loop di pioggia e tuoni ogni 10-24 s; riflessi bassi, così il cielo grigio non si specchia come una fascia bianca in fondo |
| **Neve** | ridotta (da 55 m a 230 m) | fiocchi che scendono lenti, cielo chiaro e lattiginoso |
| **Tramonto** | piena | sole basso e arancione davanti e di lato, controluce, ombre lunghe; nebbia blu-viola scuro come le montagne in controluce e riflessi ridotti, così in fondo la strada sfuma nelle montagne senza la striscia chiara all'orizzonte |
| **Notte** | ridotta | luna fredda, cielo blu notte, montagne scure, anabbaglianti accesi su tutti i mezzi, lampioni accesi con le macchie di luce sulla strada |

Meteo e ora si combinano (per esempio notte con pioggia). Come funziona:
- **Un preset per combinazione** (`Atmosphere.preset_for`): l'ora dà la base (cielo, sole, luce, nebbia) e il meteo la sposta (colori del cielo e della nebbia, scuriti di notte, sole più debole, distanza della nebbia, precipitazioni).
- **Transizioni** come interpolazione tra due preset, con il sole che ruota per la via più breve. In galleria il buio si somma: niente sole né precipitazioni, nebbia normale, luce ambiente delle lampade con un colore fisso (non dal cielo), così di notte la galleria è illuminata come di giorno.
- **Niente shader nuovi durante la partita:** cambiano solo parametri di ambiente e materiali già compilati. Le montagne hanno l'emissione sempre attiva (nera col sereno) e "spariscono" nella nebbia diventando del suo colore. Pioggia, neve e anabbaglianti vengono preparati durante il menu.
- **Mobile:** il cielo (e la luce ambiente che ne deriva) si aggiorna al massimo ogni 0.12 s durante le transizioni. Pioggia e neve sono due mesh di trattini già pronti che scorrono attorno alla camera, senza particelle e senza luci dinamiche. Anabbaglianti e lampioni hanno un solo materiale condiviso ciascuno (l'intensità si regola lì, non oggetto per oggetto); le luci dei lampioni si spengono gradualmente tra 110 e 230 m, così in nebbia non galleggiano nel nulla.
- **Leggibilità:** abbaglianti, frecce, fari e lampeggianti del cantiere sono unlit e restano visibili con ogni meteo. Il varco garantito non cambia: la visibilità ridotta è compensata dal bonus di punti.

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
| Ingresso in una tratta nuova | `countdown_go` più acuto | insieme al cartello e al bonus |
| Schianto, schermata di game over | `crash`, `game_over` | |
| Pulsanti, pausa | `ui_click` | bus UI, funziona anche in pausa |
| Loop | `road_loop`, `wind_loop`, `tunnel_loop` | volume (e tono del vento) in base a velocità, boost e buio della galleria |
| Pioggia | `rain_loop` | attutita in galleria |
| Tuono | `thunder` | col temporale, ogni 10-24 s, solo all'aperto e durante il volo |

I volumi si ritoccano in `game_audio.gd` (`BASE_DB` per effetto, `WORLD_BUS_DB`/`AMBIENCE_BUS_DB`/`UI_BUS_DB` per bus) e in `main.gd` (`_update_ambience`) per i loop. Per rigenerare i suoni: `python Tools/synth_sfx.py Audio/sfx`.
