@abstract
class_name AdService
extends Node
## Contratto per le pubblicità: il gioco parla solo con questa classe.
## Oggi c'è MockAdService (finta, per PC e prove); nella Fase 7 arriverà quella con AdMob.
## Il nodo vive sotto la radice del tree, quindi sopravvive al ricaricamento della scena.


## True se una pubblicità a premio è pronta da mostrare (altrimenti niente pannello "Continue?").
@abstract func is_rewarded_ready() -> bool


## Mostra la pubblicità a premio. on_done(rewarded: bool): true solo se è stata guardata fino in fondo.
@abstract func show_rewarded(on_done: Callable) -> void


## Mostra la pubblicità a schermo intero. on_done() viene chiamata alla chiusura, anche se non è stata caricata.
@abstract func show_interstitial(on_done: Callable) -> void
