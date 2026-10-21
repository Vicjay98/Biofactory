extends RefCounted


var section_id: String = ""

# Position normalisée sur le contour fermé.
# 0.0 = début logique du contour
# 1.0 = tour complet
var start_t: float = 0.0
var end_t: float = 1.0


var membrane_type_id: String = "basic_membrane"

# Pour l'instant toutes les membranes de la cellule
# initiale sont extérieures.
# Plus tard une section partagée entre deux cellules
# passera à false.
var is_external: bool = true

# Préparation du futur système multicellulaire.
var adjacent_cell_ids: Array[String] = []

# Actual topology junctions, independent of sampling or growth handles.
# Empty identifiers mean that this endpoint is only a technical subdivision.
var start_junction_id: String = ""
var end_junction_id: String = ""


func contains_t(value: float) -> bool:

    return (
        value >= start_t
        and value <= end_t
    )
