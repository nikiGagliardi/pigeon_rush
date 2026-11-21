class_name GameServicesClient
extends Node
## Client del server dei giochi (game-services, https://api.moesagames.ch): account anonimo, ticket di partita,
## invio dei risultati con coda offline, classifiche mondiali, saldo delle briciole d'oro, missioni giornaliere
## e negozio (oggetti posseduti in cache per poterli indossare anche offline). Il gioco non aspetta mai la rete:
## senza connessione si gioca uguale e le partite partono alla prima occasione.
##
## Come Ads, vive sotto la radice del tree: resta valido quando "Try again" ricarica la scena.
## Protocollo e difese: game-services/docs/api.md, docs/difesa-classifica.md e docs/difesa-briciole.md.
##
## Il saldo lo decide solo il server: qui c'è l'ultimo valore ricevuto (balance), da mostrare e basta.

signal account_changed
## Risposta del server per una partita inviata (vuota se il server l'ha rifiutata).
signal run_result(client_run_id: String, result: Dictionary)
signal ticket_settled
## La coda si è fermata per la rete: le partite rimaste partiranno più tardi.
signal queue_stalled
## Nuovo saldo ricevuto dal server (dopo una partita, le missioni o fetch_wallet).
signal wallet_changed(new_balance: int)
## Oggetti posseduti cambiati (negozio letto, acquisto, account cancellato).
signal owned_changed
## Cambiato il catalogo noto (oggetti in vendita e posseduti): per il pallino su SHOP.
signal shop_changed
## Missioni lette dal server: titoli di quelle completate da riscuotere che prima non lo erano.
signal missions_updated(newly_complete: PackedStringArray)

const DEFAULT_BASE_URL := "https://api.moesagames.ch"
const GAME_SLUG := "pigeon-rush"
const FILE_PATH := "user://online.json"
const SMOKE_FILE_PATH := "user://online_smoke.json"
const REQUEST_TIMEOUT := 8.0
## Il ticket arriva durante il countdown (3 s): oltre questo tempo la partita va avanti senza.
const START_TIMEOUT := 4.0
const MAX_QUEUE := 20

static var instance: GameServicesClient = null

## false: niente rete (prova automatica senza --api=...).
var enabled: bool = true
var base_url: String = DEFAULT_BASE_URL
var player_id: String = ""
var display_name: String = ""
var name_suffix: int = 0
## Briciole d'oro: ultimo saldo ricevuto dal server, -1 = mai ricevuto (si mostra 0).
var balance: int = -1
## Missioni di oggi completate e non riscosse (dall'ultima lettura delle missioni).
var claimable_missions: int = 0
## Id degli oggetti comprati (gli oggetti gratuiti non ci sono: sono di tutti). Ultimo valore dal server.
var owned_items: PackedStringArray = PackedStringArray()
## Ultimo catalogo ricevuto: id → prezzo degli oggetti in vendita e non ancora posseduti (salvato).
var shop_prices: Dictionary[String, int] = {}

## Solo per la prova automatica.
var tickets_received: int = 0
var runs_accepted: int = 0

var _token: String = ""
var _file_path: String = FILE_PATH
var _queue: Array[Dictionary] = []
var _flushing: bool = false
var _registering: bool = false
var _ticket_id: String = ""
var _ticket_pending: bool = false
## Cambia a ogni partita: un ticket arrivato in ritardo non finisce nella partita successiva.
var _run_generation: int = 0
var _crypto := Crypto.new()
## Missioni già viste complete oggi: missions_updated segnala solo le nuove.
var _complete_ids := PackedStringArray()
var _missions_date: String = ""


## Crea il client la prima volta. Opzioni da riga di comando (solo debug): --api=http://127.0.0.1:8099
static func ensure(tree: SceneTree, smoke_test: bool) -> GameServicesClient:
	if instance != null and is_instance_valid(instance):
		return instance
	instance = GameServicesClient.new()
	instance.name = "GameServicesClient"
	instance.process_mode = Node.PROCESS_MODE_ALWAYS
	var custom_url := ""
	for arg in OS.get_cmdline_user_args():
		if OS.is_debug_build() and arg.begins_with("--api="):
			custom_url = arg.trim_prefix("--api=")
	if not custom_url.is_empty():
		instance.base_url = custom_url.trim_suffix("/")
	# la prova automatica non tocca mai il server vero né l'account del giocatore
	if smoke_test:
		instance.enabled = not custom_url.is_empty()
		instance._file_path = SMOKE_FILE_PATH
		DirAccess.remove_absolute(SMOKE_FILE_PATH)
	# subito, non in _ready: Main chiede saldo e missioni prima che il client entri nell'albero, e senza
	# il token salvato _ensure_account creerebbe un account nuovo
	instance._load()
	tree.root.add_child.call_deferred(instance)
	return instance


func _ready() -> void:
	if enabled:
		_ensure_account_then_flush()


func has_account() -> bool:
	return not _token.is_empty()


## "SwiftPigeon#1234"
func full_name() -> String:
	return "%s#%04d" % [display_name, name_suffix] if has_account() else ""


static func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


# ------------------------------------------------------------------ partite

## All'inizio del countdown: chiede il ticket senza bloccare il gioco.
func begin_run(setup: RunSetup) -> void:
	_run_generation += 1
	var generation := _run_generation
	_ticket_id = ""
	if not enabled or not DevTuning.is_default():
		return # con la difficoltà modificata dal pannello DEVELOPER la partita resta fuori classifica
	_ticket_pending = true
	if not is_inside_tree():
		await ready
	if not await _ensure_account():
		_settle_ticket(generation)
		return

	var body := {
		"mode": "daily" if setup.is_daily() else "normal",
		"seed": setup.seed,
		"dailyDate": setup.daily_date if setup.is_daily() else null,
		"gameVersion": game_version(),
	}
	var response := await _request(HTTPClient.METHOD_POST, "/v1/games/%s/runs/start" % GAME_SLUG, body, true, START_TIMEOUT)
	if generation == _run_generation and response.ok:
		var run_id: Variant = response.data().get("runId", "")
		if run_id is String:
			_ticket_id = run_id as String
			tickets_received += 1
	_settle_ticket(generation)


## Id della prossima partita da inviare: run_result arriverà con lo stesso id.
func new_run_id() -> String:
	return _uuid4()


## A fine partita (anche dopo il Continua). I dati si leggono subito: la scena può essere ricaricata
## mentre si aspetta ancora il ticket.
func finish_run(client_run_id: String, session: GameSession, continues_used: int) -> void:
	if not enabled:
		return
	var generation := _run_generation
	var setup := session.setup
	var score := session.score
	var route := session.route
	var run := {
		"clientRunId": client_run_id,
		"runId": null,
		"mode": "daily" if setup.is_daily() else "normal",
		"score": score.score,
		"distanceM": snappedf(score.distance, 0.01),
		"durationMs": maxi(1, int(session.elapsed * 1000.0)),
		"gameVersion": game_version(),
		"playedAt": Time.get_datetime_string_from_system(true) + "Z",
		"stats": {
			"hits": score.hits,
			"nearMisses": score.near_misses,
			"bestCombo": score.best_combo,
			"continuesUsed": continues_used,
			# per le missioni giornaliere (nomi letti dal server: PigeonRushRules.Missions)
			"busHits": score.bus_hits,
			"truckHits": score.truck_hits,
			"nightDistance": snappedf(score.night_distance, 0.01),
			"goldenCrumbs": score.golden_crumbs,
			"lap": route.lap,
			"segments": route.segments_completed,
			"startSegment": setup.start_segment,
			"seed": setup.seed,
			"dailyDate": setup.daily_date,
			"reached": route.reached_label(),
		},
	}
	if _ticket_pending:
		await ticket_settled # al massimo START_TIMEOUT dall'inizio della partita
	if generation == _run_generation and not _ticket_id.is_empty():
		run["runId"] = _ticket_id
	_ticket_id = ""
	_queue.append(run)
	while _queue.size() > MAX_QUEUE:
		_queue.pop_front() # le più vecchie: tanto senza ticket non vanno in classifica
	_save()
	flush()


## Invia le partite in coda, una alla volta e in ordine. Si ferma al primo errore di rete (riprova più tardi).
func flush() -> void:
	if not enabled or _flushing or _queue.is_empty():
		return
	_flushing = true
	if not is_inside_tree():
		await ready
	if await _ensure_account():
		while not _queue.is_empty():
			var run: Dictionary = _queue[0]
			var response := await _request(HTTPClient.METHOD_POST, "/v1/games/%s/runs" % GAME_SLUG, run, true, REQUEST_TIMEOUT)
			var status: int = response.status
			if response.ok:
				_queue.pop_front()
				_save()
				runs_accepted += 1
				_apply_balance(response.data())
				run_result.emit(str(run.get("clientRunId", "")), response.data())
			elif status == 401:
				# account cancellato o token perso: se ne crea uno nuovo, la coda resta
				_forget_account()
				if not await _ensure_account():
					queue_stalled.emit()
					break
			elif status >= 400 and status < 500 and status != 408 and status != 429:
				# dati rifiutati: riprovare non serve
				_queue.pop_front()
				_save()
				run_result.emit(str(run.get("clientRunId", "")), {})
			else:
				queue_stalled.emit() # niente rete, server occupato o troppe richieste: alla prossima occasione
				break
	else:
		queue_stalled.emit()
	_flushing = false


## La prova automatica aspetta che la coda sia vuota prima di controllare i conteggi.
func wait_idle(max_seconds: float) -> void:
	var left := max_seconds
	while (_flushing or _ticket_pending or _registering or not _queue.is_empty()) and left > 0.0:
		await get_tree().create_timer(0.1, true, false, true).timeout
		left -= 0.1


# ------------------------------------------------------------------ classifiche

## board: "all", "week", "daily".
func fetch_leaderboard(board: String, limit: int = 50) -> Response:
	if not enabled:
		return Response.failed()
	if not is_inside_tree():
		await ready
	flush() # già che c'è rete, partono anche le partite rimaste in coda
	return await _request(HTTPClient.METHOD_GET, "/v1/games/%s/leaderboards/%s?limit=%d" % [GAME_SLUG, board, limit], null, has_account(), REQUEST_TIMEOUT)


# ------------------------------------------------------------------ briciole d'oro e missioni

## Saldo aggiornato (wallet_changed se è cambiato). Senza account non chiede niente: il saldo è 0.
func fetch_wallet() -> Response:
	if not enabled or not has_account():
		return Response.failed()
	var response := await _request(HTTPClient.METHOD_GET, "/v1/games/%s/wallet" % GAME_SLUG, null, true, REQUEST_TIMEOUT)
	if response.ok:
		_apply_balance(response.data())
	return response


## Le tre missioni di oggi con il progresso (data().missions). Crea l'account se manca.
func fetch_missions() -> Response:
	if not enabled or not await _ensure_account():
		return Response.failed()
	flush() # le partite in coda contano per le missioni
	var response := await _request(HTTPClient.METHOD_GET, "/v1/games/%s/missions" % GAME_SLUG, null, true, REQUEST_TIMEOUT)
	if response.ok:
		_apply_balance(response.data())
		_apply_missions(response.data())
	return response


## Riscuote la ricompensa (risposta come fetch_missions). 422 = non completa, 404 = non è più la missione di oggi.
func claim_mission(mission_id: String) -> Response:
	if not enabled or not await _ensure_account():
		return Response.failed()
	var path := "/v1/games/%s/missions/%s/claim" % [GAME_SLUG, mission_id.uri_encode()]
	var response := await _request(HTTPClient.METHOD_POST, path, {}, true, REQUEST_TIMEOUT)
	if response.ok:
		_apply_balance(response.data())
		_apply_missions(response.data())
	return response


## Catalogo del negozio per questa versione del gioco: data().items [{id, category, price, tier, owned,
## availableUntil}] e data().balance. Crea l'account se manca.
func fetch_shop() -> Response:
	if not enabled or not await _ensure_account():
		return Response.failed()
	var path := "/v1/games/%s/shop?version=%s" % [GAME_SLUG, game_version().uri_encode()]
	var response := await _request(HTTPClient.METHOD_GET, path, null, true, REQUEST_TIMEOUT)
	if response.ok:
		_apply_shop(response.data())
	return response


## Compra un oggetto (risposta come fetch_shop). 409 = briciole insufficienti, 404 = non più in vendita.
func buy_item(item_id: String) -> Response:
	if not enabled or not await _ensure_account():
		return Response.failed()
	var body := {"itemId": item_id, "version": game_version()}
	var response := await _request(HTTPClient.METHOD_POST, "/v1/games/%s/shop/buy" % GAME_SLUG, body, true, REQUEST_TIMEOUT)
	if response.ok:
		_apply_shop(response.data())
	return response


func _apply_shop(body: Dictionary) -> void:
	_apply_balance(body)
	var items: Variant = body.get("items", [])
	if not items is Array:
		return
	var owned := PackedStringArray()
	var prices: Dictionary[String, int] = {}
	for raw: Variant in items as Array:
		if raw is Dictionary:
			var item := raw as Dictionary
			var price := int(item.get("price", 0))
			if price <= 0:
				continue
			if item.get("owned", false) == true:
				owned.append(str(item.get("id", "")))
			else:
				prices[str(item.get("id", ""))] = price
	var owned_differs := owned != owned_items
	if not owned_differs and prices == shop_prices:
		return
	owned_items = owned
	shop_prices = prices
	_save()
	if owned_differs:
		owned_changed.emit()
	shop_changed.emit()


## C'è almeno un oggetto che questa versione sa disegnare, non posseduto e alla portata del saldo noto.
func can_afford_new_item() -> bool:
	if balance <= 0:
		return false
	for id: String in shop_prices:
		if shop_prices[id] <= balance and BirdCatalog.knows(StringName(id)):
			return true
	return false


## Secondi al prossimo cambio di missioni (mezzanotte UTC, come il server).
static func seconds_to_missions_reset() -> int:
	var now := int(Time.get_unix_time_from_system())
	return 86400 - now % 86400


func _apply_missions(body: Dictionary) -> void:
	var missions: Variant = body.get("missions", [])
	if not missions is Array:
		return
	var date := str(body.get("date", ""))
	if date != _missions_date:
		_complete_ids.clear() # giorno nuovo, missioni nuove
		_missions_date = date
	var newly := PackedStringArray()
	var claimable := 0
	for raw: Variant in missions as Array:
		if not raw is Dictionary:
			continue
		var mission := raw as Dictionary
		if mission.get("complete", false) != true or mission.get("claimed", false) == true:
			continue
		claimable += 1
		var id := str(mission.get("id", ""))
		if not _complete_ids.has(id):
			_complete_ids.append(id)
			newly.append(str(mission.get("title", "")))
	claimable_missions = claimable
	missions_updated.emit(newly)


func _apply_balance(body: Dictionary) -> void:
	var value: Variant = body.get("balance", null)
	var new_balance := -1
	if value is float:
		new_balance = int(value as float)
	elif value is int:
		new_balance = value as int
	if new_balance < 0 or new_balance == balance:
		return
	balance = new_balance
	_save()
	wallet_changed.emit(balance)


# ------------------------------------------------------------------ account

## status 400 = nome non valido, 409 = nome non disponibile.
func rename(new_name: String) -> Response:
	if not enabled or not await _ensure_account():
		return Response.failed()
	var response := await _request(HTTPClient.METHOD_PATCH, "/v1/players/me", { "displayName": new_name }, true, REQUEST_TIMEOUT)
	if response.ok:
		_apply_profile(response.data())
		_save()
		account_changed.emit()
	return response


## Cancella account, partite e record dal server (richiesto da Google Play). La coda locale si svuota.
## Alla prossima partita online si crea un account anonimo nuovo.
func delete_account() -> bool:
	if not enabled or not has_account():
		return false
	var response := await _request(HTTPClient.METHOD_DELETE, "/v1/players/me", null, true, REQUEST_TIMEOUT)
	if not response.ok and response.status != 401:
		return false
	_forget_account()
	_queue.clear()
	_save()
	account_changed.emit()
	wallet_changed.emit(balance)
	owned_changed.emit()
	shop_changed.emit()
	return true


func _ensure_account_then_flush() -> void:
	if await _ensure_account():
		flush()


## Crea l'account anonimo se manca. Più chiamate insieme aspettano la stessa richiesta.
func _ensure_account() -> bool:
	if has_account():
		return true
	if _registering:
		await account_changed
		return has_account()
	_registering = true
	var response := await _request(HTTPClient.METHOD_POST, "/v1/players", {}, false, REQUEST_TIMEOUT)
	if response.ok:
		var body := response.data()
		var token: Variant = body.get("token", "")
		if token is String:
			_token = token as String
			_apply_profile(body)
			_save()
	_registering = false
	account_changed.emit()
	return has_account()


func _apply_profile(body: Dictionary) -> void:
	var id: Variant = body.get("playerId", player_id)
	var p_name: Variant = body.get("displayName", display_name)
	var suffix: Variant = body.get("nameSuffix", name_suffix)
	player_id = id as String if id is String else player_id
	display_name = p_name as String if p_name is String else display_name
	if suffix is float:
		name_suffix = int(suffix as float)
	elif suffix is int:
		name_suffix = suffix as int


func _forget_account() -> void:
	_token = ""
	player_id = ""
	display_name = ""
	name_suffix = 0
	balance = -1
	claimable_missions = 0
	owned_items = PackedStringArray()
	shop_prices.clear()
	_complete_ids.clear()


func _settle_ticket(generation: int) -> void:
	if generation != _run_generation:
		return
	_ticket_pending = false
	ticket_settled.emit()


# ------------------------------------------------------------------ HTTP

## Risposta HTTP già letta. status 0 = nessuna risposta (rete assente, timeout).
class Response:
	extends RefCounted
	var ok: bool = false
	var status: int = 0
	var body: Variant = null

	static func failed() -> Response:
		return Response.new()

	## Il corpo come Dictionary (vuoto se non lo è).
	func data() -> Dictionary:
		return body as Dictionary if body is Dictionary else {}


func _request(method: HTTPClient.Method, path: String, body: Variant, auth: bool, timeout: float) -> Response:
	var http := HTTPRequest.new()
	http.timeout = timeout
	if not is_inside_tree():
		await tree_entered # appena creato da ensure() il client entra nell'albero al frame dopo
	add_child(http)
	var headers := PackedStringArray(["Accept: application/json"])
	var data := ""
	if body != null:
		headers.append("Content-Type: application/json")
		data = JSON.stringify(body)
	if auth and has_account():
		headers.append("Authorization: Bearer " + _token)

	if http.request(base_url + path, headers, method, data) != OK:
		http.queue_free()
		return Response.failed()
	var completed: Array = await http.request_completed
	http.queue_free()

	var response := Response.new()
	if completed[0] as int == HTTPRequest.RESULT_SUCCESS:
		response.status = completed[1] as int
	response.ok = response.status >= 200 and response.status < 300
	var bytes: PackedByteArray = completed[3]
	if bytes.size() > 0:
		response.body = JSON.parse_string(bytes.get_string_from_utf8())
	return response


## UUID versione 4 (casuale) per clientRunId.
func _uuid4() -> String:
	var b := _crypto.generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var hex := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]


# ------------------------------------------------------------------ file locale

## user://online.json: token e coda separati da save.json (record e impostazioni restano indipendenti dalla rete).
func _save() -> void:
	var file := FileAccess.open(_file_path, FileAccess.WRITE)
	if file == null:
		push_warning("GameServicesClient: impossibile scrivere %s" % _file_path)
		return
	file.store_string(JSON.stringify({
		"version": 1,
		"player_id": player_id,
		"token": _token,
		"display_name": display_name,
		"name_suffix": name_suffix,
		"balance": balance,
		"owned_items": Array(owned_items),
		"shop_prices": shop_prices,
		"queue": _queue,
	}, "\t"))
	file.close()


func _load() -> void:
	if not FileAccess.file_exists(_file_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_file_path))
	if not parsed is Dictionary:
		push_warning("GameServicesClient: %s illeggibile, si riparte senza account" % _file_path)
		return
	var d := parsed as Dictionary
	var token: Variant = d.get("token", "")
	_token = token as String if token is String else ""
	_apply_profile({
		"playerId": d.get("player_id", ""),
		"displayName": d.get("display_name", ""),
		"nameSuffix": d.get("name_suffix", 0),
	})
	var saved_owned: Variant = d.get("owned_items", [])
	if saved_owned is Array:
		for id: Variant in saved_owned as Array:
			owned_items.append(str(id))
	var saved_prices: Variant = d.get("shop_prices", {})
	if saved_prices is Dictionary:
		for id: Variant in saved_prices as Dictionary:
			var price: Variant = (saved_prices as Dictionary)[id]
			if price is float or price is int:
				shop_prices[str(id)] = int(price)
	var saved_balance: Variant = d.get("balance", null)
	if saved_balance is float:
		balance = int(saved_balance as float)
	elif saved_balance is int:
		balance = saved_balance as int
	var queue: Variant = d.get("queue", [])
	if queue is Array:
		for item: Variant in queue as Array:
			if item is Dictionary:
				_queue.append(item as Dictionary)
