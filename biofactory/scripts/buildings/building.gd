class_name Building
extends Node2D

const RecipeProcessorScript = preload(
	"res://scripts/recipes/recipe_processor.gd"
)

var data: BuildingData

var grid_position: Vector2i

var owning_cell

var is_functional: bool = false

var problems: Array[String] = []

var recipe_processor

func initialize(
    building_data: BuildingData,
    cell: Vector2i,
    cell_owner
) -> void:

    data = building_data
    grid_position = cell
    owning_cell = cell_owner

    position = Vector2.ZERO

    check_functionality()

    validate_recipes()

    setup_recipe_processor()

    queue_redraw()


    data = building_data
    grid_position = cell

    position = Vector2.ZERO

    check_functionality()

    validate_recipes()

    setup_recipe_processor()

    queue_redraw()


func check_functionality() -> void:

    problems.clear()

    if data == null:
        problems.append("Données du bâtiment manquantes")

        is_functional = false
        return

    is_functional = true


func _draw() -> void:

    if data == null:
        return

    var size := Vector2(
        data.size.x * 32,
        data.size.y * 32
    )

    draw_rect(
        Rect2(
            -size / 2.0,
            size
        ),
        Color(0.2, 0.7, 0.3)
    )

    draw_rect(
        Rect2(
            -size / 2.0,
            size
        ),
        Color.WHITE,
        false,
        2.0
    )


func validate_recipes() -> void:

    if data == null:
        return

    for recipe_id in data.supported_recipes:

        if not RecipeDatabase.has_recipe(recipe_id):

            push_error(
				"Bâtiment "
                + data.id
                + " : recette inconnue : "
                + recipe_id
            )


func setup_recipe_processor() -> void:

    if data == null:
        return

    if data.supported_recipes.is_empty():
        return

    var recipe_id: String = data.supported_recipes[0]

    var selected_recipe = RecipeDatabase.get_recipe(
        recipe_id
    )

    if selected_recipe == null:
        return

    if owning_cell == null:
        push_error(
			"Bâtiment "
            + data.id
            + " : aucune cellule propriétaire."
        )
        return

    if owning_cell.inventory == null:
        push_error(
			"Bâtiment "
            + data.id
            + " : la cellule propriétaire n'a pas d'inventaire."
        )
        return

    recipe_processor = RecipeProcessorScript.new()

    recipe_processor.configure(
        selected_recipe,
        owning_cell.inventory
    )


func _process(delta: float) -> void:

    if not is_functional:
        return

    if recipe_processor == null:
        return

    recipe_processor.process(delta)
