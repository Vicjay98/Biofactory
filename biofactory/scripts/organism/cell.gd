class_name BioCell
extends Node2D


const ResourceInventoryScript = preload(
	"res://scripts/resources/resource_inventory.gd"
)

const CellPhysiologyScript = preload("res://scripts/organism/cell_physiology.gd")

@export var physiology_profile: CellPhysiologyProfile = preload(
    "res://data/spatial/starter_physiology.tres"
)
@export var simulation_enabled: bool = true

var physiology
var oxygen_conductance: float = 0.0
var nutrient_conductance: float = 0.0


@export var cell_id: String = "starter_cell"

@export var display_name: String = "Cellule initiale"

@export var cell_manager: Node

@export_category("Starting Resources")

@export var starting_resources: Dictionary[String, float] = {}

@export var boundary: Node2D

var inventory

var buildings: Array = []

var membrane_maintenance_atp_per_second: float = 0.0


func _ready() -> void:

    add_to_group("bio_cell")

    inventory = ResourceInventoryScript.new()

    setup_starting_resources()

    if boundary == null:
        boundary = get_node_or_null("Boundary")

    if boundary != null:

        if not boundary.geometry_changed.is_connected(
            recalculate_membrane_maintenance
        ):
            boundary.geometry_changed.connect(
                recalculate_membrane_maintenance
            )

        if not boundary.membrane_topology_changed.is_connected(
            recalculate_membrane_maintenance
        ):
            boundary.membrane_topology_changed.connect(
                recalculate_membrane_maintenance
            )

        recalculate_membrane_maintenance()

    if cell_manager == null:
        push_error(
            "La cellule "
            + cell_id
            + " n'a pas de CellManager."
        )
        return

    cell_manager.register_cell(self)

    physiology = CellPhysiologyScript.new()
    physiology.configure(self, physiology_profile)


func _physics_process(delta: float) -> void:
    if simulation_enabled and physiology != null:
        physiology.advance(delta)


func get_area_m2() -> float:
    if boundary == null:
        return 0.0
    return boundary.get_area_m2()


func setup_starting_resources() -> void:

    for resource_id in starting_resources:

        var amount: float = starting_resources[
            resource_id
        ]

        inventory.set_amount(
            resource_id,
            amount
        )


func register_building(building) -> void:

    if building == null:
        return

    if building not in buildings:
        buildings.append(building)


func unregister_building(building) -> void:

    buildings.erase(building)


func get_building_count() -> int:

    return buildings.size()


func get_buildings_by_id(building_id: String) -> Array:

    var result: Array = []

    for building in buildings:

        if building == null:
            continue

        if building.data == null:
            continue

        if building.data.id == building_id:
            result.append(building)

    return result


func _exit_tree() -> void:

    if cell_manager != null:
        cell_manager.unregister_cell(self)


func recalculate_membrane_maintenance() -> void:
    membrane_maintenance_atp_per_second = 0.0
    oxygen_conductance = 0.0
    nutrient_conductance = 0.0

    if boundary == null:
        return

    for section in boundary.membrane_sections:
        var membrane_data = MembraneTypeDatabase.get_membrane_type(
            section.membrane_type_id
        )

        if membrane_data == null:
            continue

        var section_length: float = boundary.get_section_length_m(
            section
        )

        membrane_maintenance_atp_per_second += (
            section_length
            * membrane_data.maintenance_atp_per_meter_per_second
        )
        if section.is_external:
            oxygen_conductance += (
                section_length * membrane_data.oxygen_permeability_per_meter_per_second
            )
            nutrient_conductance += (
                section_length * membrane_data.nutrient_permeability_per_meter_per_second
            )


func get_membrane_maintenance_atp_per_second() -> float:
    return membrane_maintenance_atp_per_second
