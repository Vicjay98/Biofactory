class_name ConstructionManager
extends Node


@export var grid: Node2D
@export var building_manager: BuildingManager
@export var cell_manager: Node


func get_target_cell():

    if cell_manager == null:
        return null

    return cell_manager.active_cell


func can_build(
    building_data: BuildingData,
    cell: Vector2i
) -> bool:

    if building_data == null:
        return false

    var building_size := building_data.size

    for x in range(building_size.x):
        for y in range(building_size.y):

            var current_cell := cell + Vector2i(x, y)

            if not grid.is_inside_grid(current_cell):
                return false

            if not grid.is_cell_free(current_cell):
                return false

    return true


func build(
    building_data: BuildingData,
    cell: Vector2i
) -> Building:

    var target_cell = get_target_cell()

    if target_cell == null:
        push_warning(
			"Aucune cellule active pour la construction."
        )
        return null

    if not can_build(building_data, cell):
        return null

    if not can_pay_cost(
        building_data,
        target_cell
    ):
        print("Ressources insuffisantes.")
        return null

    pay_cost(
        building_data,
        target_cell
    )

    var building := Building.new()

    add_child(building)

    building.initialize(
        building_data,
        cell,
        target_cell
    )

    var building_size := building_data.size

    var center_offset := Vector2(
        (building_size.x - 1) * grid.cell_size / 2.0,
        (building_size.y - 1) * grid.cell_size / 2.0
    )

    building.position = (
        grid.grid_to_world(cell)
        + center_offset
    )

    building_manager.register_building(
        building
    )

    target_cell.register_building(
        building
    )

    occupy_building_cells(
        building_data,
        cell,
        building
    )

    return building


func occupy_building_cells(
    building_data: BuildingData,
    cell: Vector2i,
    building: Building
) -> void:

    var building_size := building_data.size

    for x in range(building_size.x):
        for y in range(building_size.y):

            var current_cell := cell + Vector2i(x, y)

            grid.occupy_cell(
                current_cell,
                building
            )


func can_pay_cost(
    building_data: BuildingData,
    target_cell
) -> bool:

    if target_cell == null:
        return false

    if target_cell.inventory == null:
        return false

    for resource_id in building_data.build_cost:

        var amount: float = building_data.build_cost[
            resource_id
        ]

        if not target_cell.inventory.has_amount(
            resource_id,
            amount
        ):
            return false

    return true


func pay_cost(
    building_data: BuildingData,
    target_cell
) -> void:

    if target_cell == null:
        return

    if target_cell.inventory == null:
        return

    for resource_id in building_data.build_cost:

        var amount: float = building_data.build_cost[
            resource_id
        ]

        target_cell.inventory.remove_resource(
            resource_id,
            amount
        )
