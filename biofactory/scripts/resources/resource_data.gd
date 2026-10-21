class_name ResourceData
extends Resource


enum ResourceType {
    MATERIAL,
    ENERGY,
    GAS,
    WASTE,
    SIGNAL,
    OTHER
}


@export_category("Identification")

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""


@export_category("Classification")

@export var resource_type: ResourceType = ResourceType.MATERIAL

@export var tags: Array[String] = []


@export_category("Simulation")

@export var transportable: bool = true
@export var storable: bool = true

@export_range(0.0, 1000.0, 0.01)
var decay_per_second: float = 0.0


@export_category("Interface")

@export var unit_name: String = "u"
