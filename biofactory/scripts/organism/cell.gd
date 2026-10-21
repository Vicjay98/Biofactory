class_name BioCell
extends Node2D


const ResourceInventoryScript = preload(
	"res://scripts/resources/resource_inventory.gd"
)


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


func get_membrane_maintenance_atp_per_second() -> float:
    return membrane_maintenance_atp_per_second
