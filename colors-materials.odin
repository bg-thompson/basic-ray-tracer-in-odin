package weekend

COLOR_BLACK :: Color3{0,0,0}
COLOR_WHITE :: Color3{1,1,1}

COLOR_RED   :: Color3{1,0,0}
COLOR_GREEN :: Color3{0,1,0}
COLOR_BLUE  :: Color3{0,0,1}

COLOR_GRAY :: Color3{0.5,0.5,0.5}
COLOR_BROWN :: Color3{0.4,0.2,0.1}

COLOR_BG    :: Color3{0.5,0.7,1.0}
COLOR_DEBUG :: Color3{1,0,1}

// Diffuse materials.
MATERIAL_UNSHINY_GRAY :: Material{MaterialType.Diffuse, COLOR_GRAY, 0.5}
MATERIAL_UNSHINY_BROWN :: Material{MaterialType.Diffuse, COLOR_BROWN, 0.5}
MATERIAL_UNSHINY_RED :: Material{MaterialType.Diffuse, COLOR_RED, 0.5}

// Metal materials.
MATERIAL_MIRROR :: Material{MaterialType.Metal, COLOR_BLACK, 0.001}
MATERIAL_STEEL  :: Material{MaterialType.Metal, COLOR_BLACK, 0.05}

// Glass materials.
MATERIAL_GLASS  :: Material{MaterialType.Glass, COLOR_BLACK, 1.5}
