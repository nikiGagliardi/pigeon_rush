# Pigeon Rush

Un piccione vola contromano in autostrada: schiva camion, cartelli e cavalcavia, centra i mezzi con la cacca per guadagnare velocità e punti.

**Stack:** Godot 4.7.2 (.NET) · C# · .NET 10 · renderer Mobile · PC + Android/iOS

## Come avviarlo

1. Installa **Godot 4.7.x – versione .NET** e il **.NET 10 SDK**.
2. Apri `project.godot` dal Project Manager di Godot.
3. Premi **Build** (martello in alto a destra), poi **F5**.

Se usi una versione di Godot diversa dalla 4.7.2, aggiorna l'`Sdk` in `PigeonRush.csproj` (es. `Godot.NET.Sdk/4.7.1`).

> **Mobile:** il target è `net10.0`. Il supporto ufficiale Godot è su .NET 8; su desktop .NET 10 funziona. Prima di spingere sul mobile fai subito un export Android di prova: se dà problemi, aggiungi
> `<TargetFramework Condition=" '$(GodotTargetPlatform)' == 'android' ">net9.0</TargetFramework>`.

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
- **Munizioni:** si parte con 6 cacche (max 10). Le **briciole** ne ricaricano 3.
- **Piume:** hai 3 vite. Dopo un colpo hai 1.6 s di invulnerabilità. Le piume bianche ridanno una vita.
- **Abbaglianti:** se sei sulla traiettoria di un mezzo (stessa corsia, sotto il tetto) tra 15 e 85 m, ti lampeggia 2-3 volte. È l'avviso per spostarti.
- **Gallerie (160-280 m):** soffitto a 5.6 m e ventilatori appesi, quindi niente volo alto. All'interno è buio: si vedono lampade, fari e abbaglianti. La camera si abbassa da sola prima del portale.
- **Lavori:** chiudono la corsia sinistra o destra per 140-220 m: barriere, coni, carrello con freccia lampeggiante e 1-3 macchinari (escavatori e rulli) che sono ostacoli. Nella corsia chiusa non passa traffico, quindi la strada resta a due corsie.
- **Difficoltà:** la velocità base sale da 16 a 30 m/s; più camion e file piene nei primi 150 s.

## Architettura

Tutta la scena viene costruita **da codice** (`Scenes/Main.tscn` contiene solo il nodo radice): niente `.tscn` o `.tres` da mantenere a mano. Mesh low-poly generati proceduralmente con vertex color (1 materiale = poche draw call su mobile).

```
Scripts/
├── Main.cs                  Regista: costruzione scena, stato di gioco, ordine di update
├── Core/
│   ├── GameConfig.cs        Tutte le costanti di bilanciamento
│   ├── GameSession.cs       Stato partita (vite, munizioni, tempo, difficoltà)
│   ├── SpeedController.cs   Velocità base + boost cumulabili
│   ├── ScoreService.cs      Punteggio, combo, statistiche
│   ├── Cells.cs             Griglia 3 corsie × 3 fasce (bitmask) per il varco garantito
│   ├── NodePool.cs          Pool generico di nodi
│   ├── Actions.cs           Input map registrata via codice
│   └── SaveData.cs          Record in user://
├── Rendering/
│   ├── LowPolyBuilder.cs    Primitive → ArrayMesh flat-shaded con vertex color
│   └── Palette.cs           Colori e materiali condivisi
├── Player/
│   ├── PigeonController.cs  Movimento X/Y con inerzia, inclinazione, invulnerabilità
│   ├── PigeonModel.cs       Piccione procedurale con ali animate
│   └── PoopSystem.cs        Mirino, traiettoria d'intercetto, macchie
├── World/
│   ├── TrafficSpawner.cs    File di traffico, strutture, raccoglibili, collisioni
│   ├── Hazard.cs            Base ostacoli (AABB manuali, sweep anti-tunneling)
│   ├── Vehicle.cs / VehicleCatalog.cs / VehicleMeshes.cs   (auto, furgoni, camion, bus, cabrio)
│   ├── HighBeamVisuals.cs   Bagliori e coni additivi degli abbaglianti (nessuna luce dinamica)
│   ├── AmbientTraffic.cs    Traffico scenografico sulla carreggiata opposta
│   ├── SignGantry.cs        Portali con cartelli verdi svizzeri
│   ├── Overpass.cs          Cavalcavia
│   ├── Tunnel.cs / TunnelMeshes.cs       Gallerie a doppia canna (buio, soffitto, ventilatori)
│   ├── RoadWorks.cs / RoadWorksMeshes.cs Cantieri con corsia chiusa e macchinari
│   ├── Pickup.cs            Briciole e piume
│   ├── RoadScroller.cs / RoadMeshes.cs   Strada a segmenti riciclati
│   ├── StructureMeshes.cs
│   └── SceneryFactory.cs    Cielo, sole, nebbia, montagne
├── CameraRig/ChaseCamera.cs Inseguimento, FOV dinamico, shake
├── Effects/                 Testi fluttuanti, esplosione di piume
└── UI/                      HUD, controlli touch, schermate
```

### Scelte chiave

- **Mondo "tapis roulant":** il piccione resta a Z = 0. Strada e strutture scorrono alla velocità del piccione, i mezzi a velocità piccione + traffico. Niente problemi di precisione dei float e il boost è solo un moltiplicatore.
- **Varco garantito:** ogni fila lascia almeno 2 celle libere su 9, e almeno una è adiacente a una cella libera della fila precedente. Le strutture (portali, cavalcavia) che arrivano nello stesso istante vengono incluse nel calcolo.
- **Collisioni manuali AABB** con sweep sull'asse Z: deterministiche, economiche, nessun "salto" dell'ostacolo ad alta velocità.
- **Guida a destra:** i mezzi contromano (verso +Z) hanno lo spartitraffico alla loro sinistra, quindi la carreggiata opposta sta sul lato +X. Lì il traffico va nella stessa direzione del piccione: a inizio partita ti sorpassa, quando acceleri sei tu a superarlo.
- **Strutture lunghe** (gallerie, cantieri): nel calcolo del varco conta l'intervallo [fronte, coda], non un singolo istante. Un mezzo non viene generato nella corsia chiusa se raggiungerebbe il cantiere prima di uscire dalla visuale.
- **Ordine di update esplicito** in `Main.TickPlaying`: niente dipendenze dall'ordine dei `_Process`.

## Roadmap

**Fase 1 (fatta):** volo, traffico (auto, furgoni, camion, bus, cabrio, auto lavate), abbaglianti di avviso, traffico sulla carreggiata opposta, portali, cavalcavia, gallerie, cantieri con corsia chiusa, cacca con mirino, boost, combo, passaggi a filo, volo radente, briciole e piume, HUD, touch, pausa, game over, record.

**Fase 2:**
- Falco che insegue se vai troppo piano
- Polizia: se la colpisci parte il "livello ricercato" con un elicottero o un drone che ti insegue
- Vento laterale, pioggia, ciclo giorno/notte
- Autovelox con flash accecante
- Power-up: mega-cacca, magnete per le briciole, scudo di piume, slow-motion
- Audio (motori in avvicinamento, effetto doppler, battito d'ali, splat)
- Opzione controllo con inclinazione (accelerometro)
- Skin del piccione, upgrade e classifica online
