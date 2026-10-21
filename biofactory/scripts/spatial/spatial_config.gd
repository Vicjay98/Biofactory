class_name SpatialConfig
extends Resource


@export_category("World Scale")

@export_range(1.0, 512.0, 1.0)
var pixels_per_meter: float = 32.0


@export_category("Cell Rules")

@export_range(0.01, 10000.0, 0.01)
var minimum_cell_area_m2: float = 4.0
