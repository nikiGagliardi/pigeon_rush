extends SceneTree
## Rigenera le icone PNG da quelle SVG in Art/Icon (dopo aver modificato un SVG):
##   godot --headless --path . --script res://Tools/render_icons.gd
##
## icon_512.png      icona per Play Console (scheda dello store) e icona del progetto
## icon_192.png      icona Android classica
## icon_*_432.png    livelli dell'icona adattiva Android (sfondo, primo piano, monocromatica)

const DIR := "res://Art/Icon/"

const OUTPUTS: Array[Array] = [
	["icon_full.svg", "icon_512.png", 512],
	["icon_full.svg", "icon_192.png", 192],
	["icon_background.svg", "icon_background_432.png", 432],
	["icon_foreground.svg", "icon_foreground_432.png", 432],
	["icon_monochrome.svg", "icon_monochrome_432.png", 432],
]


func _init() -> void:
	var failed := false
	for output: Array in OUTPUTS:
		var source := DIR + str(output[0])
		var target := DIR + str(output[1])
		var size: int = output[2]
		var svg := FileAccess.get_file_as_string(source)
		var image := Image.new()
		# il viewBox degli SVG è 432 (livelli) o 512 (icona completa): la scala porta alla misura voluta
		var base := 512.0 if str(output[0]) == "icon_full.svg" else 432.0
		if svg.is_empty() or image.load_svg_from_string(svg, size / base) != OK:
			push_error("render_icons: impossibile leggere %s" % source)
			failed = true
			continue
		if image.get_width() != size:
			image.resize(size, size, Image.INTERPOLATE_LANCZOS)
		if image.save_png(target) != OK:
			push_error("render_icons: impossibile scrivere %s" % target)
			failed = true
			continue
		print("render_icons: %s (%d px)" % [target, size])
	quit(1 if failed else 0)
