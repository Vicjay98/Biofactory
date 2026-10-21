extends Node


var catalog: RecipeCatalog = preload(
	"res://data/recipes/recipe_catalog.tres"
)

var recipes_by_id: Dictionary = {}

var database_built: bool = false


func _ready() -> void:

    ensure_built()


func ensure_built() -> void:

    if database_built:
        return

    build_database()


func build_database() -> void:

    recipes_by_id.clear()

    for recipe_resource in catalog.recipes:

        if recipe_resource == null:
            push_warning(
				"Une recette vide existe dans RecipeCatalog."
            )
            continue

        if not recipe_resource is RecipeData:
            push_error(
				"Une entrée du RecipeCatalog n'est pas une RecipeData."
            )
            continue

        var recipe_data: RecipeData = recipe_resource

        if recipe_data.id.is_empty():
            push_error(
				"Une RecipeData possède un ID vide."
            )
            continue

        if recipes_by_id.has(recipe_data.id):
            push_error(
                "ID de recette dupliqué : " + recipe_data.id
            )
            continue

        if not validate_recipe_resources(recipe_data):
            continue

        recipes_by_id[recipe_data.id] = recipe_data

    database_built = true


func validate_recipe_resources(
    recipe_data: RecipeData
) -> bool:

    for resource_id in recipe_data.inputs:

        if not ResourceDatabase.has_resource(resource_id):

            push_error(
				"Recette "
                + recipe_data.id
                + " : ressource d'entrée inconnue : "
                + resource_id
            )

            return false

    for resource_id in recipe_data.outputs:

        if not ResourceDatabase.has_resource(resource_id):

            push_error(
				"Recette "
                + recipe_data.id
                + " : ressource de sortie inconnue : "
                + resource_id
            )

            return false

    return true


func has_recipe(recipe_id: String) -> bool:

    ensure_built()

    return recipes_by_id.has(recipe_id)


func get_recipe(recipe_id: String) -> RecipeData:

    ensure_built()

    if not recipes_by_id.has(recipe_id):

        push_warning(
            "Recette inconnue : " + recipe_id
        )

        return null

    return recipes_by_id[recipe_id]


func get_all_recipes() -> Array:

    ensure_built()

    return catalog.recipes
