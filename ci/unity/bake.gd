## Generates the initial Unity world and single-draw village meshes from the original project.
extends SceneTree

const Models := preload("res://scripts/render/building_meshes.gd")
const Simulation := preload("res://scripts/simulation/simulation.gd")
const Config := preload("res://scripts/core/config.gd")
const OUTPUT := "res://Unity/Assets/Resources/"

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var config := Config.game_config()
	var buildings := Config.load_json("res://data/buildings.json")
	config["buildings"] = buildings.buildings
	config["start"] = buildings.start
	config["terrains"] = Config.load_json("res://data/terrains.json").terrains
	config["customization"] = Config.load_json("res://data/customization.json")
	var sim := Simulation.new(4147, config)
	var file := FileAccess.open(OUTPUT + "FirstWorld.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(sim.to_dict()))
	file.close()
	for frequency in [8, 12, 16, 20]:
		var grid = preload("res://scripts/simulation/hex_grid.gd").new(frequency)
		var topology := FileAccess.open(OUTPUT + "Grid%d.bytes" % frequency, FileAccess.WRITE)
		topology.store_32(grid.cell_count())
		for i in grid.cell_count():
			var dir: Vector3 = grid.centers[i]
			for value in [dir.x, dir.y, dir.z]:
				topology.store_float(value)
			topology.store_8(grid.neighbors[i].size())
			for nb in grid.neighbors[i]:
				topology.store_16(nb)
		topology.close()
	var geo := FileAccess.open(OUTPUT + "Village.bytes", FileAccess.WRITE)
	var names: Array = buildings.buildings.keys()
	names.erase("townhall")
	for level in range(1, 7):
		names.append("townhall_" + str(level))
	names.append("scaffold")
	geo.store_32(names.size())
	for id in names:
		var model: Node3D
		if id == "scaffold":
			model = Models.scaffold()
		elif str(id).begins_with("townhall_"):
			model = Models.create("townhall", int(str(id).get_slice("_", 1)))
		else:
			model = Models.create(id)
		geo.store_pascal_string(id)
		geo.store_32(model.get_child_count())
		for piece in model.get_children():
			var arrays: Array = piece.mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var color: Color = piece.material_override.albedo_color
			geo.store_32(verts.size())
			geo.store_32(indices.size())
			geo.store_8(color.r8)
			geo.store_8(color.g8)
			geo.store_8(color.b8)
			for v in verts.size():
				var pt: Vector3 = piece.transform * verts[v]
				var n: Vector3 = (piece.transform.basis.inverse().transposed() * normals[v]).normalized()
				for value in [pt.x, pt.y, pt.z, n.x, n.y, n.z]:
					geo.store_float(value)
			for index in indices:
				geo.store_16(index)
		model.free()
	geo.close()
	var bytes := FileAccess.get_file_as_bytes(OUTPUT + "Village.bytes")
	geo = FileAccess.open(OUTPUT + "Village.bytes", FileAccess.WRITE)
	geo.store_buffer(bytes.compress(FileAccess.COMPRESSION_GZIP))
	geo.close()
	quit()
