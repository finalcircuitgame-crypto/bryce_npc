-- Send Bryce's custom model and material files to clients.
-- This file is loaded automatically from lua/autorun/server.

if not SERVER then
    return
end

local RESOURCE_FILES = {
    "models/player/collection.mdl",
    "models/player/collection.vvd",
    "models/player/collection.phy",
    "models/player/collection.dx80.vtx",
    "models/player/collection.dx90.vtx",
    "materials/models/custom/Material.vmt",
    "materials/models/custom/Material.vtf"
}

for _, path in ipairs(RESOURCE_FILES) do

    if file.Exists(path, "GAME") then

        resource.AddFile(path)

    else

        ErrorNoHalt(
            "[Bryce NPC] Missing client resource: "
            .. path
            .. "\n"
        )

    end

end
