class_name BuildingData
extends Resource


@export_category("Identification")

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""


@export_category("Physical")

@export var size: Vector2i = Vector2i.ONE

@export_category("Physical Footprint")
@export_range(0.1, 10.0, 0.05)
var footprint_radius_m: float = 0.5

@export_category("Construction")

@export var build_cost: Dictionary[String, float] = {}


@export_category("Production")

@export var supported_recipes: Array[String] = []


@export_category("Requirements")

@export var required_technologies: Array[String] = []
@export var required_buildings: Array[String] = []


@export_category("Transport")

@export var accepts_transport: bool = false
@export var provides_transport: bool = false


@export_category("Specialization")

@export var specializations: Array[String] = []
