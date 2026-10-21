extends Node


var catalog: ResourceCatalog = preload(
	"res://data/resources/resource_catalog.tres"
)

var resources_by_id: Dictionary[String, ResourceData] = {}

var database_built: bool = false


func _ready() -> void:

    ensure_built()


func ensure_built() -> void:

    if database_built:
        return

    build_database()


func build_database() -> void:

    resources_by_id.clear()

    for resource_data in catalog.resources:

        if resource_data == null:
            push_warning(
				"Une ressource vide existe dans ResourceCatalog."
            )
            continue

        if resource_data.id.is_empty():
            push_error(
				"Une ResourceData possède un ID vide."
            )
            continue

        if resources_by_id.has(resource_data.id):
            push_error(
                "ID de ressource dupliqué : " + resource_data.id
            )
            continue

        resources_by_id[resource_data.id] = resource_data

    database_built = true


func has_resource(resource_id: String) -> bool:

    ensure_built()

    return resources_by_id.has(resource_id)


func get_resource(resource_id: String) -> ResourceData:

    ensure_built()

    if not resources_by_id.has(resource_id):

        push_warning(
            "Ressource inconnue : " + resource_id
        )

        return null

    return resources_by_id[resource_id]


func get_all_resources() -> Array[ResourceData]:

    ensure_built()

    return catalog.resources
