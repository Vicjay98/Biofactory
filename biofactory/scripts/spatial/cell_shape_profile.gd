class_name CellShapeProfile
extends Resource


@export_category("Dimensions")

@export_range(0.1, 100.0, 0.1)
var radius_x_m: float = 2.5

@export_range(0.1, 100.0, 0.1)
var radius_y_m: float = 2.0


@export_category("Geometry Quality")

@export_range(24, 256, 1)
var sample_count: int = 72
