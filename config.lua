Config = {}

Config.ItemName = 'CORDE'

Config.InteractionDistance = 2.4
Config.ServerValidationDistance = 6.0
Config.MaxPlacementDistance = 18.0
Config.MinRopeLength = 3.0
Config.MaxRopeLength = 20.0
Config.RopeSlack = 1.35
Config.BreakDistance = 28.0
Config.BuilderTimeout = 120

-- Type 3 (RopeMesh) : corde GTA tressée de 3 cm, plus lisible qu'un câble fin.
Config.RopeType = 3
Config.RopeOnly = false
Config.CarryProp = 'prop_cs_rope_tie_01'

Config.AttachDuration = 1900
Config.DetachDuration = 1500
Config.Animation = {
    dict = 'mini@repair',
    clip = 'fixing_a_ped',
    flag = 1
}

Config.Controls = {
    confirm = 38, -- E
    cancel = 177 -- Retour arrière
}

Config.Marker = {
    type = 2,
    scale = vec3(0.22, 0.22, 0.22),
    tractorColour = { 71, 151, 214, 210 },
    towedColour = { 232, 151, 66, 210 }
}

Config.Text = {
    selectTractor = '[E] Attacher la corde à l’arrière du véhicule tracteur',
    selectTowed = '[E] Attacher la corde à l’avant du véhicule tracté',
    cancel = '[RETOUR] Annuler',
    noVehicle = 'Approchez-vous du point d’attache d’un véhicule.',
    attachedFirst = 'Premier point fixé. Amenez la corde à l’avant du véhicule à tracter.',
    ropeReady = 'La corde est fixée. Le véhicule peut maintenant être tracté.',
    detached = 'La corde a été détachée.',
    cancelled = 'Installation de la corde annulée.'
}
