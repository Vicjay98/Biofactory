extends Node2D


signal geometry_changed
signal membrane_topology_changed


const CellGeometryScript = preload(
	"res://scripts/spatial/cell_geometry.gd"
)

const MembraneSectionStateScript = preload(
	"res://scripts/spatial/membrane_section_state.gd"
)

const SpatialConfigData = preload(
	"res://data/spatial/spatial_config.tres"
)


@export var shape_profile: Resource

@export var auto_build_on_ready: bool = true


var geometry = null

var outline: PackedVector2Array = PackedVector2Array()

var membrane_width: float = 5.0


# Sections LOGIQUES de membrane.
# Elles sont indépendantes du nombre de points
# servant à dessiner le contour.
var membrane_sections: Array = []

var next_section_id: int = 0

var selected_section_id: String = ""


func _ready() -> void:

    if not auto_build_on_ready:
        return

    if shape_profile == null:

        push_warning(
			"CellBoundary : aucun Shape Profile."
        )

        return

    build_ovoid(
        shape_profile.radius_x_m,
        shape_profile.radius_y_m,
        shape_profile.sample_count
    )


func build_ovoid(
    radius_x_m: float,
    radius_y_m: float,
    sample_count: int
) -> void:

    var safe_radius_x: float = max(
        radius_x_m,
        0.1
    )

    var safe_radius_y: float = max(
        radius_y_m,
        0.1
    )

    var safe_sample_count: int = maxi(
        sample_count,
        24
    )

    var radius_x_pixels: float = (
        safe_radius_x
        * SpatialConfigData.pixels_per_meter
    )

    var radius_y_pixels: float = (
        safe_radius_y
        * SpatialConfigData.pixels_per_meter
    )

    outline.clear()

    for index in range(
        safe_sample_count
    ):

        var angle: float = (
            TAU
            * float(index)
            / float(safe_sample_count)
        )

        var point := Vector2(
            cos(angle) * radius_x_pixels,
            sin(angle) * radius_y_pixels
        )

        outline.append(
            point
        )

    if membrane_sections.is_empty():

        initialize_membrane_topology()

    rebuild_geometry()


func initialize_membrane_topology() -> void:

    membrane_sections.clear()

    next_section_id = 0

    var section = create_membrane_section()

    section.start_t = 0.0
    section.end_t = 1.0
    section.membrane_type_id = "basic_membrane"
    section.is_external = true

    membrane_sections.append(
        section
    )

    membrane_topology_changed.emit()


func create_membrane_section():

    var section = MembraneSectionStateScript.new()

    section.section_id = (
		"membrane_section_"
        + str(next_section_id)
    )

    next_section_id += 1

    return section


func rebuild_geometry() -> void:

    geometry = CellGeometryScript.new()

    geometry.configure(
        outline,
        SpatialConfigData.pixels_per_meter
    )

    geometry_changed.emit()

    queue_redraw()


func set_outline(
    new_outline: PackedVector2Array
) -> void:

    if new_outline.size() < 3:
        return

    outline = new_outline.duplicate()

    rebuild_geometry()


func get_t_for_outline_index(
    index: int
) -> float:

    if outline.is_empty():
        return 0.0

    var safe_index: int = posmod(
        index,
        outline.size()
    )

    return (
        float(safe_index)
        / float(outline.size())
    )


func get_section_at_t(
    value: float
):

    var safe_value: float = clamp(
        value,
        0.0,
        1.0
    )

    for section in membrane_sections:

        if section.contains_t(
            safe_value
        ):

            return section

    return null


func get_section_for_edge(
    edge_index: int
):

    if outline.is_empty():
        return null

    var edge_middle_t: float = (
        (
            float(
                posmod(
                    edge_index,
                    outline.size()
                )
            )
            + 0.5
        )
        / float(outline.size())
    )

    return get_section_at_t(
        edge_middle_t
    )


func ensure_section_boundary_at_outline_index(
    index: int
) -> float:

    var split_t: float = get_t_for_outline_index(
        index
    )

    # 0 / 1 est déjà la coupure logique
    # du contour fermé.
    if split_t <= 0.00001:
        return 0.0

    split_section_at_t(
        split_t
    )

    return split_t


func split_section_at_t(
    split_t: float
) -> bool:

    if split_t <= 0.00001:
        return false

    if split_t >= 0.99999:
        return false

    var section = get_section_at_t(
        split_t
    )

    if section == null:
        return false

    if abs(
        split_t - section.start_t
    ) <= 0.00001:

        return false

    if abs(
        split_t - section.end_t
    ) <= 0.00001:

        return false

    var old_end_t: float = section.end_t

    var new_section = create_membrane_section()

    # La nouvelle portion hérite de toutes les propriétés
    # de la membrane qu'on vient de couper.
    new_section.start_t = split_t
    new_section.end_t = old_end_t

    new_section.membrane_type_id = (
        section.membrane_type_id
    )

    new_section.is_external = (
        section.is_external
    )

    new_section.adjacent_cell_ids = (
        section.adjacent_cell_ids.duplicate()
    )

    section.end_t = split_t

    var section_index: int = (
        membrane_sections.find(
            section
        )
    )

    membrane_sections.insert(
        section_index + 1,
        new_section
    )

    membrane_topology_changed.emit()

    queue_redraw()

    return true


func set_section_membrane_type(
    section_id: String,
    new_type_id: String
) -> bool:

    for section in membrane_sections:

        if section.section_id != section_id:
            continue

        section.membrane_type_id = (
            new_type_id
        )

        membrane_topology_changed.emit()

        queue_redraw()

        return true

    return false


func get_membrane_color(
    membrane_type_id: String
) -> Color:

    var membrane_data = (
        MembraneTypeDatabase.get_membrane_type(
            membrane_type_id
        )
    )

    if membrane_data == null:

        return Color(
            0.8,
            0.8,
            0.8
        )

    return membrane_data.display_color


func _draw() -> void:

    if outline.size() < 3:
        return

    var valid_size: bool = (
        geometry.is_large_enough(
            SpatialConfigData.minimum_cell_area_m2
        )
    )

    var fill_color := Color(
        0.15,
        0.55,
        0.45,
        0.20
    )

    if not valid_size:

        fill_color = Color(
            0.75,
            0.15,
            0.15,
            0.20
        )

    draw_colored_polygon(
        outline,
        fill_color
    )

    for edge_index in range(
        outline.size()
    ):

        var next_index: int = (
            (edge_index + 1)
            % outline.size()
        )

        var section = get_section_for_edge(
            edge_index
        )

        var membrane_color := Color(
            0.45,
            0.85,
            0.95
        )

        var current_width: float = membrane_width

        if section != null:

            membrane_color = get_membrane_color(
                section.membrane_type_id
            )

            var membrane_data = (
                MembraneTypeDatabase.get_membrane_type(
                    section.membrane_type_id
                )
            )

            if membrane_data != null:

                current_width = (
                    membrane_data.display_width
                )

        if (
            section != null
            and section.section_id
            == selected_section_id
        ):

            membrane_color = (
                membrane_color.lightened(
                    0.35
                )
            )

            current_width += 4.0

        draw_line(
            outline[edge_index],
            outline[next_index],
            membrane_color,
            current_width,
            true
        )


func contains_local_point(
    local_point: Vector2
) -> bool:

    if geometry == null:
        return false

    return geometry.contains_point(
        local_point
    )


func get_area_m2() -> float:

    if geometry == null:
        return 0.0

    return geometry.get_area_m2()


func get_perimeter_m() -> float:

    if geometry == null:
        return 0.0

    return geometry.get_perimeter_m()


func set_selected_section(
    section_id: String
) -> void:

    selected_section_id = section_id

    queue_redraw()


func clear_selected_section() -> void:

    selected_section_id = ""

    queue_redraw()


func get_section_length_m(
    section
) -> float:

    if section == null:
        return 0.0

    if outline.size() < 2:
        return 0.0

    var length_pixels: float = 0.0

    for edge_index in range(
        outline.size()
    ):

        var edge_section = get_section_for_edge(
            edge_index
        )

        if edge_section != section:
            continue

        var next_index: int = (
            (edge_index + 1)
            % outline.size()
        )

        length_pixels += outline[
            edge_index
        ].distance_to(
            outline[next_index]
        )

    return (
        length_pixels
        / SpatialConfigData.pixels_per_meter
    )


func get_section_at_local_position(
    local_position: Vector2,
    max_distance: float
):

    var nearest_section = null
    var nearest_distance: float = max_distance

    for edge_index in range(
        outline.size()
    ):

        var next_index: int = (
            (edge_index + 1)
            % outline.size()
        )

        var distance: float = (
            get_distance_to_segment(
                local_position,
                outline[edge_index],
                outline[next_index]
            )
        )

        if distance > nearest_distance:
            continue

        nearest_distance = distance

        nearest_section = get_section_for_edge(
            edge_index
        )

    return nearest_section


func get_distance_to_segment(
    point: Vector2,
    segment_start: Vector2,
    segment_end: Vector2
) -> float:

    var segment: Vector2 = (
        segment_end - segment_start
    )

    var segment_length_squared: float = (
        segment.length_squared()
    )

    if segment_length_squared <= 0.0001:

        return point.distance_to(
            segment_start
        )

    var t: float = (
        (point - segment_start).dot(
            segment
        )
        / segment_length_squared
    )

    t = clamp(
        t,
        0.0,
        1.0
    )

    var closest_point: Vector2 = (
        segment_start
        + segment * t
    )

    return point.distance_to(
        closest_point
    )


func get_section_length_m_for_outline(
    section,
    target_outline: PackedVector2Array
) -> float:

    if section == null:
        return 0.0

    if target_outline.size() < 2:
        return 0.0

    if target_outline.size() != outline.size():
        return 0.0

    var length_pixels: float = 0.0

    for edge_index in range(
        target_outline.size()
    ):

        var edge_section = get_section_for_edge(
            edge_index
        )

        if edge_section != section:
            continue

        var next_index: int = (
            (edge_index + 1)
            % target_outline.size()
        )

        length_pixels += (
            target_outline[edge_index]
            .distance_to(
                target_outline[next_index]
            )
        )

    return (
        length_pixels
        / SpatialConfigData.pixels_per_meter
    )
