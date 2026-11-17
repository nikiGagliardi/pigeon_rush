# Pigeon Rush

Un piccione vola contromano in autostrada: schiva camion, cartelli e cavalcavia, centra i mezzi con la cacca per guadagnare velocità e punti.

**Stack:** Godot 4.7.2 (.NET) · C# · .NET 10 · renderer Mobile · PC + Android/iOS

## Come avviarlo

1. Installa **Godot 4.7.x – versione .NET** e il **.NET 10 SDK**.
2. Apri `project.godot` dal Project Manager di Godot.
3. Premi **Build** (martello in alto a destra), poi **F5**.

Se usi una versione di Godot diversa dalla 4.7.2, aggiorna l'`Sdk` in `PigeonRush.csproj` (es. `Godot.NET.Sdk/4.7.1`).

> **Target framework:** desktop su `net10.0`, Android su `net9.0` (condizione nel `.csproj`), perché il template di export Android di Godot supporta solo .NET 9. Il codice usa solo API disponibili in entrambe le versioni.

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
- **Un colpo e sei fuori:** al primo impatto con un mezzo o un ostacolo il piccione è spacciato. Niente vite, niente invulnerabilità.
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
├── Main.cs                  Regista: costruzione scena, stato di gioco, ordine di update
├── Core/
│   ├── GameConfig.cs        Tutte le costanti di bilanciamento
│   ├── GameSession.cs       Stato partita (munizioni, tempo, difficoltà, game over)
│   ├── SpeedController.cs   Velocità base + boost cumulabili
│   ├── ScoreService.cs      Punteggio, combo, statistiche
│   ├── Cells.cs             Griglia 3 corsie × 3 fasce (bitmask) per il varco garantito
│   ├── NodePool.cs          Pool generico di nodi
│   ├── Actions.cs           Input map registrata via codice
│   └── SaveData.cs          Record in user://
├── Rendering/
│   ├── LowPolyBuilder.cs    Primitive → ArrayMesh flat-shaded con vertex color
│   ├── AssetWarmup.cs       Pre-costruzione mesh e pre-compilazione shader durante il menu
│   └── Palette.cs           Colori e materiali condivisi
├── Player/
│   ├── PigeonController.cs  Movimento X/Y con inerzia, inclinazione, caduta finale
│   ├── PigeonModel.cs       Piccione procedurale con ali animate
│   └── PoopSystem.cs        Mirino, traiettoria d'intercetto, macchie
├── World/
│   ├── TrafficSpawner.cs    File di traffico, strutture, raccoglibili, collisioni
│   ├── Hazard.cs            Base ostacoli (AABB manuali, sweep anti-tunneling)
│   ├── Vehicle.cs / VehicleCatalog.cs / VehicleMeshes.cs   (auto, furgoni, camion, bus, cabrio)
│   ├── HighBeamVisuals.cs   Bagliori e coni additivi degli abbaglianti (nessuna luce dinamica)
│   ├── IndicatorVisuals.cs  Frecce gialle lampeggianti per i cambi di corsia
│   ├── AmbientTraffic.cs    Traffico scenografico sulla carreggiata opposta
│   ├── SignGantry.cs        Portali con cartelli verdi svizzeri
│   ├── Overpass.cs          Cavalcavia
│   ├── Tunnel.cs / TunnelMeshes.cs       Gallerie a doppia canna (buio, soffitto, ventilatori)
│   ├── RoadWorks.cs / RoadWorksMeshes.cs Cantieri con corsia chiusa e macchinari
│   ├── Pickup.cs            Briciole (ricarica cacca)
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
- **Niente scatti alla prima comparsa:** tutti i mesh procedurali (gallerie, cantieri, veicoli…) vengono costruiti durante il menu, uno per frame, e disegnati una volta in miniatura dietro al pannello del titolo, così geometria e shader sono già pronti quando parte la partita. In più l'export Android ha lo **Shader Baker** attivo.
- **Ordine di update esplicito** in `Main.TickPlaying`: niente dipendenze dall'ordine dei `_Process`.

## Roadmap

**Fase 1 (fatta):** volo, traffico (auto, furgoni, camion, bus, cabrio, auto lavate), abbaglianti di avviso, cambi di corsia con freccia, traffico sulla carreggiata opposta, portali, cavalcavia, gallerie, cantieri con corsia chiusa, cacca con mirino, boost, combo, passaggi a filo, volo radente, briciole, morte al primo colpo, HUD, touch, pausa, game over, record.

**Fase 2:**
- Falco che insegue se vai troppo piano
- Polizia: se la colpisci parte il "livello ricercato" con un elicottero o un drone che ti insegue
- Meteo e ora del giorno (vedi sotto), vento laterale
- Autovelox con flash accecante
- Power-up: mega-cacca, magnete per le briciole, scudo di piume, slow-motion
- Audio (motori in avvicinamento, effetto doppler, battito d'ali, splat)
- Opzione controllo con inclinazione (accelerometro)
- Skin del piccione, upgrade e classifica online

### Idea: meteo e ora del giorno (non ancora implementato)

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
