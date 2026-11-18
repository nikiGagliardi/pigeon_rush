class_name Ads
extends RefCounted
## Punto d'accesso unico alle pubblicità. Lo stato è statico: resta valido quando "Try again" ricarica la scena.

static var service: AdService = null
static var policy := InterstitialPolicy.new()


## Crea il servizio la prima volta, sotto la radice del tree (fuori dalla scena che viene ricaricata).
static func ensure(tree: SceneTree) -> AdService:
	if service == null or not is_instance_valid(service):
		service = MockAdService.new()
		service.name = "AdService"
		# durante il caricamento della scena la radice è occupata: aggiunta differita
		tree.root.add_child.call_deferred(service)
	return service
