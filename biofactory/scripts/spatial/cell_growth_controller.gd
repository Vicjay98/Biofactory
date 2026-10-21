extends Node2D


signal growth_committed(
    area_added_m2: float,
    perimeter_added_m: float
)


const SpatialConfigData = preload(
	"res://data/spatial/spatial_config.tres"
)

const MembraneGrowthEconomyScript = preload(
	"res://scripts/membranes/membrane_growth_economy.gd"
)


@export var boundary: Node2D
@export var owning_cell: Node2D


@export_category("Selection")

@export var grab_distance_pixels: float = 14.0


@export_category("Growth")

@export var max_growth_m: float = 1.5
@export var minimum_commit_growth_m: float = 0.05


var anchor_a_index: int = -1
var anchor_b_index: int = -1

var selected_path: Array[int] = []

var dragging: bool = false

var drag_reference_index: int = -1

var drag_start_local: Vector2 = Vector2.ZERO
var drag_outward_direction: Vector2 = Vector2.ZERO

var original_outline: PackedVector2Array = PackedVector2Array()
var preview_outline: PackedVector2Array = PackedVector2Array()

var preview_valid: bool = false

var mouse_world_position: Vector2 = Vector2.ZERO

var growth_economy = MembraneGrowthEconomyScript.new()

var preview_resource_costs: Dictionary[String, float] = {}


func _ready() -> void:

    if owning_cell == null:
        owning_cell = get_parent()


func _process(_delta: float) -> void:

    mouse_world_position = get_global_mouse_position()

    if dragging:
        update_growth_preview()

    queue_redraw()


func _unhandled_input(
    event: InputEvent
) -> void:

    if event is InputEventMouseButton:

        if event.button_index == MOUSE_BUTTON_LEFT:

            if event.pressed:
                handle_left_press()

            else:

                if dragging:
                    finish_growth()

        elif (
            event.button_index == MOUSE_BUTTON_RIGHT
            and event.pressed
        ):

            reset_selection()


func handle_left_press() -> void:

    if boundary == null:
        return

    if boundary.geometry == null:
        return

    if anchor_a_index < 0:
        select_anchor_a()
        return

    if anchor_b_index < 0:
        select_anchor_b()
        return

    start_span_drag()


func select_anchor_a() -> void:

    var mouse_local: Vector2 = boundary.to_local(
        mouse_world_position
    )

    var index: int = find_nearest_outline_index(
        mouse_local
    )

    if not is_index_close_enough(
        index,
        mouse_local
    ):
        return

    anchor_a_index = index

    boundary.ensure_section_boundary_at_outline_index(
        anchor_a_index
    )

    queue_redraw()


func select_anchor_b() -> void:

    var mouse_local: Vector2 = boundary.to_local(
        mouse_world_position
    )

    var index: int = find_nearest_outline_index(
        mouse_local
    )

    if not is_index_close_enough(
        index,
        mouse_local
    ):
        return

    if index == anchor_a_index:
        return

    anchor_b_index = index

    boundary.ensure_section_boundary_at_outline_index(
        anchor_b_index
    )

    queue_redraw()


func start_span_drag() -> void:

    var mouse_local: Vector2 = boundary.to_local(
        mouse_world_position
    )

    var clicked_index: int = find_nearest_outline_index(
        mouse_local
    )

    if not is_index_close_enough(
        clicked_index,
        mouse_local
    ):
        return

    if (
        clicked_index == anchor_a_index
        or clicked_index == anchor_b_index
    ):
        return

    var forward_path: Array[int] = get_forward_path(
        anchor_a_index,
        anchor_b_index
    )

    var backward_path: Array[int] = get_backward_path(
        anchor_a_index,
        anchor_b_index
    )

    if clicked_index in forward_path:

        selected_path = forward_path

    elif clicked_index in backward_path:

        selected_path = backward_path

    else:

        return

    if selected_path.size() < 3:
        return

    drag_reference_index = clicked_index

    original_outline = boundary.outline.duplicate()

    preview_outline = original_outline.duplicate()

    drag_start_local = mouse_local

    var centroid: Vector2 = calculate_centroid(
        original_outline
    )

    var reference_point: Vector2 = original_outline[
        drag_reference_index
    ]

    drag_outward_direction = (
        reference_point - centroid
    )

    if drag_outward_direction.length() <= 0.001:
        return

    drag_outward_direction = (
        drag_outward_direction.normalized()
    )

    dragging = true
    preview_valid = false


func update_growth_preview() -> void:

    if not dragging:
        return

    if selected_path.size() < 3:
        return

    var mouse_local: Vector2 = boundary.to_local(
        mouse_world_position
    )

    var drag_vector: Vector2 = (
        mouse_local - drag_start_local
    )

    var growth_pixels: float = drag_vector.dot(
        drag_outward_direction
    )

    var maximum_growth_pixels: float = (
        max_growth_m
        * SpatialConfigData.pixels_per_meter
    )

    growth_pixels = clamp(
        growth_pixels,
        0.0,
        maximum_growth_pixels
    )

    var centroid: Vector2 = calculate_centroid(
        original_outline
    )

    var new_outline: PackedVector2Array = (
        original_outline.duplicate()
    )

    var last_path_position: int = (
        selected_path.size() - 1
    )

    for path_position in range(
        selected_path.size()
    ):

        var outline_index: int = selected_path[
            path_position
        ]

        var t: float = (
            float(path_position)
            / float(last_path_position)
        )

        var weight: float = sin(
            t * PI
        )

        var original_point: Vector2 = original_outline[
            outline_index
        ]

        var point_direction: Vector2 = (
            original_point - centroid
        )

        if point_direction.length() <= 0.001:

            point_direction = drag_outward_direction

        else:

            point_direction = (
                point_direction.normalized()
            )

        new_outline[
            outline_index
        ] = (
            original_point
            + point_direction
            * growth_pixels
            * weight
        )

    preview_outline = new_outline

    var minimum_growth_pixels: float = (
        minimum_commit_growth_m
        * SpatialConfigData.pixels_per_meter
    )

    var new_area_m2: float = calculate_area_m2(
        preview_outline
    )

    preview_resource_costs = (
        growth_economy.calculate_cost(
            boundary,
            original_outline,
            preview_outline
        )
    )

    var can_afford_growth: bool = false

    if (
        owning_cell != null
        and owning_cell.inventory != null
    ):

        can_afford_growth = (
            growth_economy.can_afford(
                owning_cell.inventory,
                preview_resource_costs
            )
        )

    preview_valid = (
        growth_pixels >= minimum_growth_pixels
        and new_area_m2
        >= SpatialConfigData.minimum_cell_area_m2
        and can_afford_growth
    )


func finish_growth() -> void:

    if not dragging:
        return

    if preview_valid:

        if owning_cell == null:
            reset_selection()
            return

        if owning_cell.inventory == null:
            reset_selection()
            return

        var paid: bool = (
            growth_economy.pay_cost(
                owning_cell.inventory,
                preview_resource_costs
            )
        )

        if not paid:
            reset_selection()
            return

        var old_area: float = calculate_area_m2(
            original_outline
        )

        var old_perimeter: float = calculate_perimeter_m(
            original_outline
        )

        var new_area: float = calculate_area_m2(
            preview_outline
        )

        var new_perimeter: float = calculate_perimeter_m(
            preview_outline
        )

        boundary.set_outline(
            preview_outline
        )

        var area_added: float = (
            new_area - old_area
        )

        var perimeter_added: float = (
            new_perimeter - old_perimeter
        )

        growth_committed.emit(
            area_added,
            perimeter_added
        )

        print(
            "Croissance A-B validée | +",
            snapped(
                area_added,
                0.01
            ),
            " m² | +",
            snapped(
                perimeter_added,
                0.01
            ),
			" m de membrane"
        )

    reset_selection()


func reset_selection() -> void:

    anchor_a_index = -1
    anchor_b_index = -1

    selected_path.clear()

    dragging = false
    drag_reference_index = -1

    original_outline = PackedVector2Array()
    preview_outline = PackedVector2Array()

    preview_valid = false

    preview_resource_costs.clear()

    queue_redraw()


func get_forward_path(
    start_index: int,
    end_index: int
) -> Array[int]:

    var result: Array[int] = []

    var point_count: int = boundary.outline.size()

    var current_index: int = start_index

    result.append(
        current_index
    )

    var safety: int = 0

    while (
        current_index != end_index
        and safety <= point_count
    ):

        current_index = (
            (current_index + 1)
            % point_count
        )

        result.append(
            current_index
        )

        safety += 1

    return result


func get_backward_path(
    start_index: int,
    end_index: int
) -> Array[int]:

    var result: Array[int] = []

    var point_count: int = boundary.outline.size()

    var current_index: int = start_index

    result.append(
        current_index
    )

    var safety: int = 0

    while (
        current_index != end_index
        and safety <= point_count
    ):

        current_index = posmod(
            current_index - 1,
            point_count
        )

        result.append(
            current_index
        )

        safety += 1

    return result


func find_nearest_outline_index(
    local_position: Vector2
) -> int:

    if boundary == null:
        return -1

    if boundary.outline.is_empty():
        return -1

    var nearest_index: int = -1
    var nearest_distance: float = INF

    for index in range(
        boundary.outline.size()
    ):

        var point: Vector2 = boundary.outline[
            index
        ]

        var distance: float = point.distance_to(
            local_position
        )

        if distance < nearest_distance:

            nearest_distance = distance
            nearest_index = index

    return nearest_index


func is_index_close_enough(
    index: int,
    local_position: Vector2
) -> bool:

    if index < 0:
        return false

    var point: Vector2 = boundary.outline[
        index
    ]

    var distance: float = point.distance_to(
        local_position
    )

    return distance <= grab_distance_pixels


func calculate_area_m2(
    points: PackedVector2Array
) -> float:

    if points.size() < 3:
        return 0.0

    var area_pixels: float = 0.0

    for index in range(
        points.size()
    ):

        var current_point: Vector2 = points[
            index
        ]

        var next_index: int = (
            (index + 1)
            % points.size()
        )

        var next_point: Vector2 = points[
            next_index
        ]

        area_pixels += (
            current_point.x
            * next_point.y
        )

        area_pixels -= (
            next_point.x
            * current_point.y
        )

    area_pixels = abs(
        area_pixels * 0.5
    )

    var scale_squared: float = (
        SpatialConfigData.pixels_per_meter
        * SpatialConfigData.pixels_per_meter
    )

    return (
        area_pixels
        / scale_squared
    )


func calculate_perimeter_m(
    points: PackedVector2Array
) -> float:

    if points.size() < 2:
        return 0.0

    var perimeter_pixels: float = 0.0

    for index in range(
        points.size()
    ):

        var next_index: int = (
            (index + 1)
            % points.size()
        )

        perimeter_pixels += points[
            index
        ].distance_to(
            points[next_index]
        )

    return (
        perimeter_pixels
        / SpatialConfigData.pixels_per_meter
    )


func calculate_centroid(
    points: PackedVector2Array
) -> Vector2:

    if points.is_empty():
        return Vector2.ZERO

    var centroid: Vector2 = Vector2.ZERO

    for point in points:
        centroid += point

    return (
        centroid
        / float(points.size())
    )


func has_active_selection() -> bool:

    return (
        anchor_a_index >= 0
        or anchor_b_index >= 0
        or dragging
    )


func _draw() -> void:

    if boundary == null:
        return

    draw_anchor(
        anchor_a_index,
        Color(
            1.0,
            0.75,
            0.2
        )
    )

    draw_anchor(
        anchor_b_index,
        Color(
            1.0,
            0.55,
            0.15
        )
    )

    if not dragging:
        return

    if preview_outline.size() < 3:
        return

    var display_points := PackedVector2Array()

    for point in preview_outline:

        var world_point: Vector2 = (
            boundary.to_global(
                point
            )
        )

        display_points.append(
            to_local(
                world_point
            )
        )

    var fill_color := Color(
        0.2,
        0.8,
        0.35,
        0.18
    )

    var outline_color := Color(
        0.3,
        1.0,
        0.45,
        0.8
    )

    if not preview_valid:

        fill_color = Color(
            0.9,
            0.15,
            0.15,
            0.18
        )

        outline_color = Color(
            1.0,
            0.25,
            0.25,
            0.8
        )

    draw_colored_polygon(
        display_points,
        fill_color
    )

    var closed_points := PackedVector2Array(
        display_points
    )

    closed_points.append(
        display_points[0]
    )

    draw_polyline(
        closed_points,
        outline_color,
        3.0,
        true
    )


func draw_anchor(
    index: int,
    color: Color
) -> void:

    if index < 0:
        return

    if index >= boundary.outline.size():
        return

    var world_position: Vector2 = (
        boundary.to_global(
            boundary.outline[index]
        )
    )

    var local_position: Vector2 = to_local(
        world_position
    )

    draw_circle(
        local_position,
        7.0,
        color
    )
