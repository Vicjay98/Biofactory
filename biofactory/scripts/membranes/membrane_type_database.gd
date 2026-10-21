extends Node


var catalog: MembraneTypeCatalog = preload(
	"res://data/membranes/membrane_type_catalog.tres"
)

var membrane_types_by_id: Dictionary = {}

var database_built: bool = false


func _ready() -> void:

    ensure_built()


func ensure_built() -> void:

    if database_built:
        return

    build_database()


func build_database() -> void:

    membrane_types_by_id.clear()

    for membrane_resource in catalog.membrane_types:

        if membrane_resource == null:

            push_warning(
				"Une membrane vide existe dans MembraneTypeCatalog."
            )

            continue

        if not membrane_resource is MembraneTypeData:

            push_error(
				"Une entrée de MembraneTypeCatalog "
                + "n'est pas une MembraneTypeData."
            )

            continue

        var membrane_data = membrane_resource

        if membrane_data.id.is_empty():

            push_error(
				"Une MembraneTypeData possède un ID vide."
            )

            continue

        if membrane_types_by_id.has(
            membrane_data.id
        ):

            push_error(
				"ID de membrane dupliqué : "
                + membrane_data.id
            )

            continue

        validate_build_cost(
            membrane_data
        )

        membrane_types_by_id[
            membrane_data.id
        ] = membrane_data

    database_built = true


func validate_build_cost(
    membrane_data
) -> void:

    for resource_id in membrane_data.build_cost_per_meter:

        if ResourceDatabase.has_resource(
            resource_id
        ):

            continue

        push_error(
			"Membrane "
                + membrane_data.id
                + " : ressource inconnue dans le coût : "
                + resource_id
        )


func has_membrane_type(
    membrane_type_id: String
) -> bool:

    ensure_built()

    return membrane_types_by_id.has(
        membrane_type_id
    )


func get_membrane_type(
    membrane_type_id: String
):

    ensure_built()

    if not membrane_types_by_id.has(
        membrane_type_id
    ):

        push_warning(
			"Type de membrane inconnu : "
                + membrane_type_id
        )

        return null

    return membrane_types_by_id[
        membrane_type_id
    ]


func get_all_membrane_types() -> Array:

    ensure_built()

    return catalog.membrane_types
