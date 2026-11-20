class_name LowPolyBuilder
extends RefCounted
## Compone più primitive (box, cilindri, sfere…) in un unico ArrayMesh con
## normali per faccia (look low-poly) e vertex color.
## Superficie 0 = illuminata, superficie 1 = unlit (luci, fari).
##
## Prestazioni: chiedere i vertici a Godot (PrimitiveMesh + get_mesh_arrays) è costoso.
## Le forme standard vengono generate una sola volta in forma "unitaria" e messe in cache,
## già espanse in triangoli con la normale di faccia: box 1×1×1, sfera di raggio 1,
## cilindro alto 1 con base di raggio 1, prisma 1×1×1. Ogni chiamata trasforma
## l'intero array in un colpo solo (Transform3D * PackedVector3Array, codice nativo):
## nessun ciclo per vertice in GDScript.

enum ShapeType { BOX, SPHERE, CYLINDER, PRISM }


## Triangoli già espansi (3 vertici per faccia) e normale di faccia per ogni vertice, in spazio locale.
class ShapeData:
	var vertices: PackedVector3Array
	var normals: PackedVector3Array

	func _init(v: PackedVector3Array, n: PackedVector3Array) -> void:
		vertices = v
		normals = n


class Surface:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()


static var _shape_cache: Dictionary[int, ShapeData] = {}

## Trasformazione applicata a tutte le forme aggiunte dopo: per costruire un oggetto (casa, mucca…) nelle sue
## coordinate e poi posarlo e ruotarlo in un colpo solo. Rimetterla a IDENTITY alla fine.
var origin := Transform3D.IDENTITY

var _lit := Surface.new()
var _unlit := Surface.new()


## Aggiunge una primitiva qualsiasi (non in cache: usare per forme rare, es. TorusMesh).
func add_primitive(mesh: PrimitiveMesh, transform: Transform3D, color: Color, unlit: bool = false) -> LowPolyBuilder:
	return _add_shape(_to_shape_data(mesh), transform, color, unlit)


func box(size: Vector3, center: Vector3, color: Color, rotation_deg: Vector3 = Vector3.ZERO, unlit: bool = false) -> LowPolyBuilder:
	return _add_shape(_get_shape(ShapeType.BOX, 0, 0, 0), _make_transform(center, rotation_deg, size), color, unlit)


## Box definito da estremi min/max (comodo per volumi architettonici).
func block(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, color: Color, unlit: bool = false) -> LowPolyBuilder:
	return box(Vector3(x1 - x0, y1 - y0, z1 - z0), Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5), color, Vector3.ZERO, unlit)


func cylinder(top_radius: float, bottom_radius: float, height: float, center: Vector3, color: Color,
		segments: int = 8, rotation_deg: Vector3 = Vector3.ZERO, unlit: bool = false) -> LowPolyBuilder:
	# forma unitaria: base larga di raggio 1, altezza 1; l'altra base in proporzione
	var wide_on_top := top_radius > bottom_radius
	var wide := top_radius if wide_on_top else bottom_radius
	var narrow := bottom_radius if wide_on_top else top_radius
	var ratio := narrow / wide if wide > 0.0 else 1.0
	var shape := _get_shape(ShapeType.CYLINDER, segments, roundi(ratio * 1000.0), 1 if wide_on_top else 0)
	var w := maxf(wide, 1e-4)
	return _add_shape(shape, _make_transform(center, rotation_deg, Vector3(w, height, w)), color, unlit)


func cone(radius: float, height: float, base_center: Vector3, color: Color, segments: int = 6) -> LowPolyBuilder:
	return cylinder(0.0, radius, height, base_center + Vector3(0.0, height * 0.5, 0.0), color, segments)


func sphere(radius: float, center: Vector3, scale: Vector3, color: Color,
		segments: int = 8, rings: int = 5, rotation_deg: Vector3 = Vector3.ZERO, unlit: bool = false) -> LowPolyBuilder:
	return _add_shape(_get_shape(ShapeType.SPHERE, segments, rings, 0), _make_transform(center, rotation_deg, scale * radius), color, unlit)


func prism(size: Vector3, center: Vector3, color: Color, rotation_deg: Vector3 = Vector3.ZERO) -> LowPolyBuilder:
	return _add_shape(_get_shape(ShapeType.PRISM, 0, 0, 0), _make_transform(center, rotation_deg, size), color, false)


## Ruota con asse lungo X (per veicoli che guardano verso +Z).
func wheel(x: float, z: float, radius: float, width: float = 0.28) -> LowPolyBuilder:
	return cylinder(radius, radius, width, Vector3(x, radius, z), Palette.TIRE, 8, Vector3(0.0, 0.0, 90.0))


func build() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	_add_surface(mesh, _lit, Palette.lit())
	_add_surface(mesh, _unlit, Palette.unlit())
	return mesh


## Numero di forme distinte in cache (utile per verificare che la cache lavori).
static func cached_shape_count() -> int:
	return _shape_cache.size()


func _add_shape(shape: ShapeData, transform: Transform3D, color: Color, unlit: bool) -> LowPolyBuilder:
	var target := _unlit if unlit else _lit
	var count := shape.vertices.size()
	if count == 0:
		return self
	if origin != Transform3D.IDENTITY:
		transform = origin * transform
	# Le normali di faccia si trasformano con l'inversa trasposta: restano perpendicolari
	# anche con scale non uniformi e mantengono il verso (scale positive).
	var basis := transform.basis
	var normal_basis := basis.inverse().transposed() if absf(basis.determinant()) > 1e-12 else basis
	var normal_xform := Transform3D(normal_basis, Vector3.ZERO)
	target.vertices.append_array(transform * shape.vertices)
	target.normals.append_array(normal_xform * shape.normals)
	var colors := PackedColorArray()
	colors.resize(count)
	colors.fill(color)
	target.colors.append_array(colors)
	return self


static func _get_shape(type: ShapeType, a: int, b: int, c: int) -> ShapeData:
	var key := ((type * 256 + a) * 4096 + b) * 2 + c
	var cached: ShapeData = _shape_cache.get(key)
	if cached != null:
		return cached
	var data := _to_shape_data(_create_unit_shape(type, a, b, c))
	_shape_cache[key] = data
	return data


static func _create_unit_shape(type: ShapeType, a: int, b: int, c: int) -> PrimitiveMesh:
	match type:
		ShapeType.BOX:
			var box_mesh := BoxMesh.new()
			box_mesh.size = Vector3.ONE
			return box_mesh
		ShapeType.PRISM:
			var prism_mesh := PrismMesh.new()
			prism_mesh.size = Vector3.ONE
			return prism_mesh
		ShapeType.SPHERE:
			var sphere_mesh := SphereMesh.new()
			sphere_mesh.radius = 1.0
			sphere_mesh.height = 2.0
			sphere_mesh.radial_segments = a
			sphere_mesh.rings = b
			return sphere_mesh
		_:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 1.0 if c == 1 else b / 1000.0
			cyl.bottom_radius = b / 1000.0 if c == 1 else 1.0
			cyl.height = 1.0
			cyl.radial_segments = a
			cyl.rings = 1
			return cyl


## Espande gli indici in triangoli e calcola la normale di faccia (orientata con le normali
## originali della primitiva, robusto rispetto al winding). Scarta i triangoli degeneri.
static func _to_shape_data(mesh: PrimitiveMesh) -> ShapeData:
	var arrays := mesh.get_mesh_arrays()
	var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	var count := indices.size() if not indices.is_empty() else src_v.size()
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var has_normals := src_n.size() == src_v.size()
	var i := 0
	while i + 2 < count:
		var i0 := indices[i] if not indices.is_empty() else i
		var i1 := indices[i + 1] if not indices.is_empty() else i + 1
		var i2 := indices[i + 2] if not indices.is_empty() else i + 2
		i += 3
		var a := src_v[i0]
		var b := src_v[i1]
		var c := src_v[i2]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			continue # triangolo degenere (es. punta dei coni)
		n = n.normalized()
		if has_normals and n.dot(src_n[i0] + src_n[i1] + src_n[i2]) < 0.0:
			n = -n
		out_v.append(a)
		out_v.append(b)
		out_v.append(c)
		out_n.append(n)
		out_n.append(n)
		out_n.append(n)
	return ShapeData.new(out_v, out_n)


static func _add_surface(mesh: ArrayMesh, surface: Surface, material: Material) -> void:
	if surface.vertices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = surface.vertices
	arrays[Mesh.ARRAY_NORMAL] = surface.normals
	arrays[Mesh.ARRAY_COLOR] = surface.colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)


static func _make_transform(center: Vector3, rotation_deg: Vector3, scale: Vector3) -> Transform3D:
	var radians := Vector3(deg_to_rad(rotation_deg.x), deg_to_rad(rotation_deg.y), deg_to_rad(rotation_deg.z))
	var basis := Basis.from_euler(radians) * Basis.from_scale(scale)
	return Transform3D(basis, center)
