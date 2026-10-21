class_name OrganicBuilding
extends Node2D


const SpatialConfigData = preload(
    "res://data/spatial/spatial_config.tres"
)

const RecipeProcessorScript = preload("res://scripts/recipes/recipe_processor.gd")

var recipe_processor


@export var data: BuildingData
@export var owning_cell: Node2D


var is_functional: bool = true
var problems: Array[String] = []

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var last_valid_position: Vector2 = Vector2.ZERO
var placement_valid: bool = true


func _ready() -> void:
    add_to_group("organic_building")

    if owning_cell != null:
        owning_cell.register_building(self)

    last_valid_position = position

    queue_redraw()


func _exit_tree() -> void:
    if is_instance_valid(owning_cell):
        owning_cell.unregister_building(self)


## Called by the owning cell so exchange, production and upkeep have one order.
func simulate(delta: float) -> float:
    if data == null or owning_cell == null or owning_cell.inventory == null:
        return 0.0
    if data.supported_recipes.is_empty():
        return 0.0
    if recipe_processor == null:
        var recipe = RecipeDatabase.get_recipe(data.supported_recipes[0])
        if recipe == null:
            return 0.0
        recipe_processor = RecipeProcessorScript.new()
        recipe_processor.configure(recipe, owning_cell.inventory)
    problems.clear()
    if not recipe_processor.cycle_running:
        for resource_id in recipe_processor.recipe.inputs:
            var required: float = recipe_processor.recipe.inputs[resource_id]
            if not owning_cell.inventory.has_amount(resource_id, required):
                problems.append("Manque de " + ResourceDatabase.get_resource(resource_id).display_name)
    is_functional = problems.is_empty()
    var atp_before: float = owning_cell.inventory.get_amount("atp")
    recipe_processor.process(delta)
    queue_redraw()
    return maxf(owning_cell.inventory.get_amount("atp") - atp_before, 0.0)


func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        handle_mouse_button(event)

    if event is InputEventMouseMotion:
        handle_mouse_motion(event)


func handle_mouse_button(
    event: InputEventMouseButton
) -> void:
    if event.button_index != MOUSE_BUTTON_LEFT:
        return

    if event.pressed:
        try_start_drag()
        return

    if dragging:
        finish_drag()


func handle_mouse_motion(
    _event: InputEventMouseMotion
) -> void:
    if not dragging:
        return

    update_drag_position()


func try_start_drag() -> void:
    var mouse_local: Vector2 = to_local(
        get_global_mouse_position()
    )

    if not contains_local_point(
        mouse_local
    ):
        return

    dragging = true

    drag_offset = (
        global_position
        - get_global_mouse_position()
    )

    last_valid_position = position

    get_viewport().set_input_as_handled()

    queue_redraw()


func update_drag_position() -> void:
    if owning_cell == null:
        return

    var desired_global_position: Vector2 = (
        get_global_mouse_position()
        + drag_offset
    )

    global_position = desired_global_position

    placement_valid = is_current_position_valid()

    queue_redraw()


func finish_drag() -> void:
    dragging = false

    if placement_valid:
        last_valid_position = position

    else:
        position = last_valid_position
        placement_valid = true

    get_viewport().set_input_as_handled()

    queue_redraw()


func is_current_position_valid() -> bool:
    if owning_cell == null:
        return false

    if owning_cell.boundary == null:
        return false

    if not is_fully_inside_cell():
        return false

    if overlaps_another_building():
        return false

    return true


func is_fully_inside_cell() -> bool:
    var radius_pixels: float = (
        get_footprint_radius_pixels()
    )

    var sample_count: int = 24

    for sample_index in range(
        sample_count
    ):
        var angle: float = (
            TAU
            * float(sample_index)
            / float(sample_count)
        )

        var sample_local: Vector2 = Vector2(
            cos(angle),
            sin(angle)
        ) * radius_pixels

        var sample_global: Vector2 = to_global(
            sample_local
        )

        var boundary_local: Vector2 = (
            owning_cell.boundary.to_local(
                sample_global
            )
        )

        if not owning_cell.boundary.contains_local_point(
            boundary_local
        ):
            return false

    return true


func overlaps_another_building() -> bool:
    var buildings: Array[Node] = (
        get_tree().get_nodes_in_group(
            "organic_building"
        )
    )

    for other in buildings:
        if other == self:
            continue

        if not other is OrganicBuilding:
            continue

        if other.owning_cell != owning_cell:
            continue

        var minimum_distance: float = (
            get_footprint_radius_pixels()
            + other.get_footprint_radius_pixels()
        )

        var actual_distance: float = (
            global_position.distance_to(
                other.global_position
            )
        )

        if actual_distance < minimum_distance:
            return true

    return false


func get_footprint_radius_m() -> float:
    if data == null:
        return 0.5

    return data.footprint_radius_m


func get_footprint_radius_pixels() -> float:
    return (
        get_footprint_radius_m()
        * SpatialConfigData.pixels_per_meter
    )


func contains_local_point(
    local_point: Vector2
) -> bool:
    return (
        local_point.length()
        <= get_footprint_radius_pixels()
    )


func _draw() -> void:
    var radius_pixels: float = (
        get_footprint_radius_pixels()
    )

    var fill_color := Color(
        0.35,
        0.75,
        0.55,
        0.75
    )

    var outline_color := Color(
        0.65,
        1.0,
        0.8,
        1.0
    )

    if not is_functional:
        fill_color = Color(0.75, 0.4, 0.18, 0.75)

    if dragging and not placement_valid:
        fill_color = Color(
            0.85,
            0.2,
            0.2,
            0.65
        )

        outline_color = Color(
            1.0,
            0.35,
            0.35,
            1.0
        )

    draw_circle(
        Vector2.ZERO,
        radius_pixels,
        fill_color
    )

    draw_arc(
        Vector2.ZERO,
        radius_pixels,
        0.0,
        TAU,
        48,
        outline_color,
        3.0,
        true
    )
