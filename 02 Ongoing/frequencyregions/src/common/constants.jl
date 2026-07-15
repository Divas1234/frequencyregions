const DAMPING_RANGE = 2:0.25:15
const MIN_DAMPING = minimum(DAMPING_RANGE)
const MAX_DAMPING = maximum(DAMPING_RANGE)

const PERCENTAGE_BASE = 100
const FREQUENCY_BASE = 50

const OUTPUT_REL_PATH = "res/single_area/all_vertices.txt"
const MULTIAREA_OUTPUT_REL_PATH = "res/multi_area/all_vertices_multiarea.txt"

# Nature/Science-inspired style constants
const PLOT_FONT_FAMILY = "Helvetica"
const COLOR_UPPER_BOUND = "#00468B"      # Classic Navy
const COLOR_LOWER_BOUND = "#00A087"      # Muted Teal
const COLOR_ROCOF_LIMIT = "#AD002A"      # Crimson Red
const COLOR_FIT_CURVE = "#925E9F"        # Muted Purple
const COLOR_DAMPING_BOUNDS = "#7F7F7F"   # Slate Grey
const COLOR_FEASIBLE_ISO = "#FDAF91"     # Peach / Soft Orange
const COLOR_FEASIBLE_CON = "#4DBBD5"     # Soft Sky Blue
const COLOR_FEASIBLE_DYN = "#8491B4"     # Steel Blue
const COLOR_VERIFY_A = "#3C5488"         # Secure point color (Navy)
const COLOR_VERIFY_B = "#FDAF91"         # Boundary point color (Orange)
const COLOR_VERIFY_C = "#AD002A"         # Insecure point color (Red)

