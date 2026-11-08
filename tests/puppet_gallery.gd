extends SceneTree
## Renders every character puppet in a row (with a few expressions/poses)
## and saves a screenshot. Usage:
##   xvfb-run godot --path . --resolution 1440x900 -s tests/puppet_gallery.gd

const Puppet := preload("res://src/world/puppet.gd")


func _initialize() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#3a3556")
	bg.size = Vector2(1440, 900)
	root.add_child(bg)
	var chars := ["wren", "odile", "tobias", "mari", "june", "felix", "bram", "theo"]
	var exprs := ["neutral", "happy", "sad", "surprised", "angry", "thinking", "shy", "neutral"]
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	for i in chars.size():
		var p := Puppet.new()
		p.configure(data[chars[i]].puppet)
		p.position = Vector2(110 + i * 170, 400)
		p.scale = Vector2(1.25, 1.25)
		root.add_child(p)
		var q := Puppet.new()
		q.configure(data[chars[i]].puppet)
		q.position = Vector2(110 + i * 170, 820)
		q.scale = Vector2(1.25, 1.25)
		q.expression = exprs[i]
		q.facing = -1 if i % 2 == 0 else 1
		if i == 3:
			q.holding = true
		if i == 4:
			q.walking = true
			q.walk_phase = 1.2
		if i == 6:
			q.talking = true
		root.add_child(q)
	for _k in 12:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png("res://build/puppets.png")
	print("saved puppets.png ", img.get_size())
	quit()
