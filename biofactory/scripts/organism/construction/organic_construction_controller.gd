extends Node2D


const SpatialConfigData = preload(
    "res://data/spatial/spatial_config.tres"
)

const OrganicBuildingScene = preload(
    "res://scene/buildings/organic_building.tscn"
)


@export var boundary: Node2D
@export var owning_cell: Node2D
@export var building_data: BuildingData

@export var construction_active: bool = false


var preview_position: Vector2 = Vector2.ZERO
var preview_valid: bool = false


func _process(_delta: float) -> void:
    if not construction_active:
        queue_redraw()
        return

    if boundary == null:
        return

    if owning_cell == null:
        return

    if building_data == null:
        return

    preview_position = to_local(
        get_global_mouse_position()
    )

    preview_valid = is_preview_valid()

    queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
    if not construction_active:
        return

    if not event is InputEventMouseButton:
        return

    if not event.pressed:
        return

    if event.button_index == MOUSE_BUTTON_RIGHT:
        construction_active = false
        queue_redraw()
        get_viewport().set_input_as_handled()
        return

    if event.button_index != MOUSE_BUTTON_LEFT:
        return

    if not preview_valid:
        return

    construct_building()

    get_viewport().set_input_as_handled()


func is_preview_valid() -> bool:
    if not can_afford_building():
        return false

    if not is_fully_inside_cell():
        return false

    if overlaps_existing_building():
        return false

    return true


func can_afford_building() -> bool:
    if owning_cell.inventory == null:
        return false

    for resource_id in building_data.build_cost:
        var required_amount: float = (
            building_data.build_cost[resource_id]
        )

        if not owning_cell.inventory.has_amount(
            resource_id,
            required_amount
        ):
            return false

    return true


func is_fully_inside_cell() -> bool:
    var radius_pixels: float = (
        building_data.footprint_radius_m
        * SpatialConfigData.pixels_per_meter
    )

    var sample_count: int = 24

    for sample_index in range(sample_count):
        var angle: float = (
            TAU
            * float(sample_index)
            / float(sample_count)
        )

        var offset: Vector2 = Vector2(
            cos(angle),
            sin(angle)
        ) * radius_pixels

        var point_in_controller: Vector2 = (
            preview_position + offset
        )

        var point_global: Vector2 = to_global(
            point_in_controller
        )

        var point_in_boundary: Vector2 = (
            boundary.to_local(
                point_global
            )
        )

        if not boundary.contains_local_point(
            point_in_boundary
        ):
            return false

    return true


func overlaps_existing_building() -> bool:
    var radius_pixels: float = (
        building_data.footprint_radius_m
        * SpatialConfigData.pixels_per_meter
    )

    var preview_global: Vector2 = to_global(
        preview_position
    )

    var buildings: Array[Node] = (
        get_tree().get_nodes_in_group(
            "organic_building"
        )
    )

    for other in buildings:
        if not other is OrganicBuilding:
            continue

        if other.owning_cell != owning_cell:
            continue

        var minimum_distance: float = (
            radius_pixels
            + other.get_footprint_radius_pixels()
        )

        var distance: float = (
            preview_global.distance_to(
                other.global_position
            )
        )

        if distance < minimum_distance:
            return true

    return false


func pay_build_cost() -> bool:
    if not can_afford_building():
        return false

    for resource_id in building_data.build_cost:
        var amount: float = (
            building_data.build_cost[resource_id]
        )

        owning_cell.inventory.remove_resource(
            resource_id,
            amount
        )

    return true


func construct_building() -> void:
    if not pay_build_cost():
        return

    var building = OrganicBuildingScene.instantiate()

    building.data = building_data
    building.owning_cell = owning_cell

    owning_cell.add_child(building)

    var target_global_position: Vector2 = (
        to_global(
            preview_position
        )
    )

    building.global_position = (
        target_global_position
    )


func _draw() -> void:
    if not construction_active:
        return

    if building_data == null:
        return

    var radius_pixels: float = (
        building_data.footprint_radius_m
        * SpatialConfigData.pixels_per_meter
    )

    var fill_color := Color(
        0.25,
        0.85,
        0.4,
        0.35
    )

    var outline_color := Color(
        0.45,
        1.0,
        0.6,
        0.9
    )

    if not preview_valid:
        fill_color = Color(
            0.9,
            0.2,
            0.2,
            0.35
        )

        outline_color = Color(
            1.0,
            0.35,
            0.35,
            0.9
        )

    draw_circle(
        preview_position,
        radius_pixels,
        fill_color
    )

    draw_arc(
        preview_position,
        radius_pixels,
        0.0,
        TAU,
        48,
        outline_color,
        2.0,
        true
    )
