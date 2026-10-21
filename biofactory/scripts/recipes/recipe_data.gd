class_name RecipeData
extends Resource


@export_category("Identification")

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""


@export_category("Process")

@export_range(0.01, 3600.0, 0.01)
var duration: float = 1.0


@export_category("Resources")

@export var inputs: Dictionary[String, float] = {}
@export var outputs: Dictionary[String, float] = {}


@export_category("Classification")

@export var tags: Array[String] = []
