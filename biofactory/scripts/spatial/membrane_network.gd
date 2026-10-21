extends Node2D


signal network_changed
signal regions_changed


const JunctionScript = preload(
	"res://scripts/spatial/membrane_junction.gd"
)

const SectionScript = preload(
	"res://scripts/spatial/membrane_section.gd"
)

const CellRegionScript = preload(
	"res://scripts/spatial/membrane_cell_region.gd"
)

const CellGeometryScript = preload(
	"res://scripts/spatial/cell_geometry.gd"
)

const SpatialConfigData = preload(
	"res://data/spatial/spatial_config.tres"
)

var junctions: Array = []
var sections: Array = []

var detected_regions: Array = []

var next_junction_id: int = 0


func create_junction(
    world_position: Vector2
):

    var junction = JunctionScript.new()

    add_child(junction)

    junction.position = to_local(
        world_position
    )

    junction.junction_id = (
		"junction_"
        + str(next_junction_id)
    )

    next_junction_id += 1

    junctions.append(junction)

    network_changed.emit()

    return junction


func create_section(
    start_junction,
    end_junction
):

    if start_junction == null:
        return null

    if end_junction == null:
        return null

    if start_junction == end_junction:
        return null

    if has_section_between(
        start_junction,
        end_junction
    ):
        return null

    var section = SectionScript.new()

    add_child(section)

    section.setup(
        start_junction,
        end_junction
    )

    sections.append(section)

    rebuild_regions()

    network_changed.emit()

    return section


func has_section_between(
    junction_a,
    junction_b
) -> bool:

    for section in sections:

        var same_direction: bool = (
            section.start_junction == junction_a
            and section.end_junction == junction_b
        )

        var opposite_direction: bool = (
            section.start_junction == junction_b
            and section.end_junction == junction_a
        )

        if same_direction or opposite_direction:
            return true

    return false


func find_section_between(
    junction_a,
    junction_b
):

    for section in sections:

        var same_direction: bool = (
            section.start_junction == junction_a
            and section.end_junction == junction_b
        )

        var opposite_direction: bool = (
            section.start_junction == junction_b
            and section.end_junction == junction_a
        )

        if same_direction or opposite_direction:
            return section

    return null


func build_face_outline(
    face: Array
) -> PackedVector2Array:

    var outline := PackedVector2Array()

    if face.size() < 3:
        return outline

    for index in range(face.size()):

        var current_junction = face[index]

        var next_index: int = (
            (index + 1) % face.size()
        )

        var next_junction = face[next_index]

        var section_points: PackedVector2Array = (
            get_section_points_between(
                current_junction,
                next_junction
            )
        )

        if section_points.is_empty():
            return PackedVector2Array()

        # On ignore le dernier point pour éviter
        # de dupliquer les jonctions.
        for point_index in range(
            section_points.size() - 1
        ):

            outline.append(
                section_points[point_index]
            )

    return outline


func get_section_points_between(
    junction_a,
    junction_b
) -> PackedVector2Array:

    var result := PackedVector2Array()

    var section = find_section_between(
        junction_a,
        junction_b
    )

    if section == null:
        return result

    var section_points: PackedVector2Array = (
        section.get_sampled_points()
    )

    if section.start_junction == junction_a:

        for point in section_points:
            result.append(point)

    else:

        for index in range(
            section_points.size() - 1,
            -1,
            -1
        ):

            result.append(
                section_points[index]
            )

    return result


func find_nearest_junction(
    world_position: Vector2,
    max_distance: float
):

    var nearest = null

    var nearest_distance: float = max_distance

    for junction in junctions:

        var distance: float = (
            junction.global_position.distance_to(
                world_position
            )
        )

        if distance <= nearest_distance:

            nearest = junction
            nearest_distance = distance

    return nearest


func get_total_membrane_length() -> float:

    var total: float = 0.0

    for section in sections:

        total += section.get_length()

    return total


func get_neighbors(junction) -> Array:

    var neighbors: Array = []

    for section in sections:

        if section.start_junction == junction:

            if section.end_junction not in neighbors:
                neighbors.append(
                    section.end_junction
                )

        elif section.end_junction == junction:

            if section.start_junction not in neighbors:
                neighbors.append(
                    section.start_junction
                )

    return neighbors


func get_next_face_neighbor(
    previous_junction,
    current_junction
):

    var neighbors: Array = get_neighbors(
        current_junction
    )

    if neighbors.is_empty():
        return null

    if neighbors.size() == 1:
        return neighbors[0]

    var back_direction: Vector2 = (
        previous_junction.position
        - current_junction.position
    )

    var back_angle: float = back_direction.angle()

    var best_neighbor = null

    var best_delta: float = TAU + 1.0

    for neighbor in neighbors:

        if neighbor == previous_junction:
            continue

        var candidate_direction: Vector2 = (
            neighbor.position
            - current_junction.position
        )

        var candidate_angle: float = (
            candidate_direction.angle()
        )

        var delta: float = fposmod(
            back_angle - candidate_angle,
            TAU
        )

        if delta < best_delta:

            best_delta = delta
            best_neighbor = neighbor

    if best_neighbor == null:
        return previous_junction

    return best_neighbor


func get_directed_edge_key(
    start_junction,
    end_junction
) -> String:

    return (
        start_junction.junction_id
        + ">"
        + end_junction.junction_id
    )


func trace_face(
    start_junction,
    second_junction,
    visited_edges: Dictionary
) -> Array:

    var face: Array = []

    var previous_junction = start_junction
    var current_junction = second_junction

    var start_key: String = get_directed_edge_key(
        start_junction,
        second_junction
    )

    var maximum_steps: int = (
        sections.size() * 2 + 10
    )

    for _step in range(maximum_steps):

        var edge_key: String = get_directed_edge_key(
            previous_junction,
            current_junction
        )

        if edge_key == start_key and not face.is_empty():
            return face

        if visited_edges.has(edge_key):
            return []

        visited_edges[edge_key] = true

        face.append(
            previous_junction
        )

        var next_junction = get_next_face_neighbor(
            previous_junction,
            current_junction
        )

        if next_junction == null:
            return []

        previous_junction = current_junction
        current_junction = next_junction

    return []


func calculate_signed_area(
    points: PackedVector2Array
) -> float:

    if points.size() < 3:
        return 0.0

    var area: float = 0.0

    for index in range(
        points.size()
    ):

        var current_point: Vector2 = (
            points[index]
        )

        var next_index: int = (
            (index + 1) % points.size()
        )

        var next_point: Vector2 = (
            points[next_index]
        )

        area += (
            current_point.x
            * next_point.y
        )

        area -= (
            next_point.x
            * current_point.y
        )

    return area * 0.5


func rebuild_regions() -> void:

    clear_regions()

    if sections.size() < 3:
        return

    var visited_edges: Dictionary = {}

    for section in sections:

        try_create_region_from_direction(
            section.start_junction,
            section.end_junction,
            visited_edges
        )

        try_create_region_from_direction(
            section.end_junction,
            section.start_junction,
            visited_edges
        )

    regions_changed.emit()


func try_create_region_from_direction(
    start_junction,
    end_junction,
    visited_edges: Dictionary
) -> void:

    var edge_key: String = get_directed_edge_key(
        start_junction,
        end_junction
    )

    if visited_edges.has(edge_key):
        return

    var face: Array = trace_face(
        start_junction,
        end_junction,
        visited_edges
    )

    if face.size() < 3:
        return

    var outline: PackedVector2Array = (
        build_face_outline(face)
    )

    if outline.size() < 3:
        return

    var signed_area: float = (
        calculate_signed_area(
            outline
        )
    )

    if signed_area <= 1.0:
        return

    create_visual_region(
        outline
    )


func create_visual_region(
    points: PackedVector2Array
) -> void:

    var geometry = CellGeometryScript.new()

    geometry.configure(
        points,
        SpatialConfigData.pixels_per_meter
    )

    var region = CellRegionScript.new()

    add_child(region)

    region.setup(
        geometry,
        SpatialConfigData.minimum_cell_area_m2
    )

    detected_regions.append(
        region
    )


func clear_regions() -> void:

    for region in detected_regions:

        if is_instance_valid(region):
            region.queue_free()

    detected_regions.clear()
