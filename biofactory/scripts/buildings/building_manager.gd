class_name BuildingManager
extends Node


var buildings: Array[Building] = []


func register_building(building: Building) -> void:

    if building not in buildings:
        buildings.append(building)


func unregister_building(building: Building) -> void:

    buildings.erase(building)


func get_building_at(cell: Vector2i) -> Building:

    for building in buildings:

        if building.grid_position == cell:
            return building

    return null
