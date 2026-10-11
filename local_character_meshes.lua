-- Local Character Meshes v1.1
-- Client-only appearance changes to Players.LocalPlayer.Character.
-- Requires executor filesystem APIs and getcustomasset with .mesh support.
-- Catalog metadata/model requests use Roblox's public APIs.
-- No global asset replacement or changes to other players' characters.
-- R15 ApplyMesh also updates LOCAL collision geometry; it is not shader-only.

local ROOT = "LocalCharacterMeshes"
local VERSION = "1.1.0"
local env = type(getgenv) == "function" and getgenv() or _G
local FS = {
    isfile = isfile, isfolder = isfolder, makefolder = makefolder,
    readfile = readfile, writefile = writefile, listfiles = listfiles,
    asset = getcustomasset or getsynasset, delete = delfile,
}
for _, name in ipairs({"isfile", "isfolder", "makefolder", "readfile", "writefile", "listfiles", "asset"}) do
    assert(type(FS[name]) == "function", "[LocalCharacterMeshes] Missing executor API: " .. name)
end
assert(Content and Content.fromUri, "[LocalCharacterMeshes] This client needs the Content.fromUri API.")

local Players = game:GetService("Players")
local Assets = game:GetService("AssetService")
local Http = game:GetService("HttpService")
local Marketplace = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local player = assert(Players.LocalPlayer, "[LocalCharacterMeshes] Run this on the client.")

local DEFAULT_CONFIG = [[{
  "R6": {},
  "R15": {}
}]]
local DEFAULT_ITEMS = [[{"assets":[],"bundles":[]}]]
local AVATAR_HELP = [[AVATAR ITEMS BY ID

local avatar = getgenv().LocalCharacterMeshes
avatar.Wear(123456789)        -- catalog ASSET ID, not a raw mesh/texture ID
avatar.WearBundle(12345)     -- catalog BUNDLE ID (different ID namespace)
avatar.Remove(123456789)
avatar.RemoveBundle(12345)
avatar.ClearItems()          -- keep custom meshes; remove requested IDs
avatar.ListItems()           -- returns {assets={...}, bundles={...}}
avatar.Reload()
avatar.Stop()                -- restore original local appearance

IDs are saved in LocalCharacterMeshes/avatar_items.json after successful loading.
You can also edit {"assets":[123456789],"bundles":[12345]} then call Reload().
Unowned available catalog items may be previewed locally. This does not purchase
items, change your account avatar, or make the appearance visible to other users.
Deleted, private, restricted, invalid and rig-incompatible assets can fail.
Supported: classic clothes, face, body parts, rigid accessories, layered clothing,
eyebrows and eyelashes when accepted by the native Roblox avatar builder.
Models, tools, decals, raw meshes, animation packs, makeup/profile backgrounds
and every other non-supported type are rejected. Literally ANY ID is impossible.
Bundle body/accessory assets are expanded; nonwearable bundle components skipped.

With IDs enabled, a native local visual avatar follows your character's existing
Motor6D pose. Your actual character remains the player/camera/physics character.
Only its body/accessories are hidden locally; equipped tools are kept visible.
The visual has no collisions/touch/query participation. Native accessory welds,
WrapLayers, cages, textures and skinning data are retained by Roblox's builder.
Matching custom meshes override the requested body geometry on the visual.
Classic clothing STILL needs Roblox body UVs; layered clothes need matching cages.
Custom rigs, procedural animations, facial expressions and game-specific effects
are not guaranteed to match. First-person visual hiding uses the camera focus.
Native R6/R15, catalog visibility, executor support and actual rendering need an
in-game test; this script has only syntax and simulated lifecycle checks here.
]]
local README = [[LOCAL CHARACTER MESHES

1. Execute local_character_meshes.lua once.
2. Put NATIVE ROBLOX .mesh files in LocalCharacterMeshes/R6 or /R15
   inside your EXECUTOR's workspace directory. This is NOT Roblox Workspace.
3. Execute the script again, or run:
   getgenv().LocalCharacterMeshes.Reload()
4. Restore your original appearance and disconnect the loader:
   getgenv().LocalCharacterMeshes.Stop()

Only your current LocalPlayer.Character is changed on this client.
Other characters/NPCs keep their meshes. Other players see your normal avatar.
The loader follows respawns in this session. Re-execute after joining a new server.
Avatar ID commands and the local visual-avatar mode are described in AVATAR_ITEMS.txt.

AUTOMATIC FILENAMES
R6: Head.mesh, Torso.mesh, LeftArm.mesh, RightArm.mesh,
    LeftLeg.mesh, RightLeg.mesh.
Spaces, underscores, hyphens and letter case are ignored for automatic matching:
Left Arm.mesh and left_arm.mesh both match Left Arm. Use only one per body part.
R15: Head.mesh, UpperTorso.mesh, LowerTorso.mesh,
     LeftUpperArm.mesh, LeftLowerArm.mesh, LeftHand.mesh,
     RightUpperArm.mesh, RightLowerArm.mesh, RightHand.mesh,
     LeftUpperLeg.mesh, LeftLowerLeg.mesh, LeftFoot.mesh,
     RightUpperLeg.mesh, RightLowerLeg.mesh, RightFoot.mesh.
Missing files leave that body part unchanged. The rig is detected automatically.

FILE REQUIREMENTS
- .mesh means Roblox's serialized mesh format (header starts with 'version').
  Renaming .obj/.fbx/.glb to .mesh does NOT convert it.
- Prepare separate meshes for the body parts of the rig you actually use.
  Use the matching Roblox body template, coordinates and orientation.
  This does not import or retarget a single full-body model or custom skeleton.
- Classic shirts, pants and graphic T-shirts remain in the original character.
  They use Roblox's own clothing renderer. Meshes need the CORRECT ROBLOX
  BODY UV layout, not just any UV map. UVs are not generated or remapped here.
- R6 body parts use CharacterMesh.MeshContent, never clothing-incompatible
  SpecialMeshes as a body fallback. The current client must support that API.
- R6 Part heads use SpecialMesh, with scale [1,1,1] by default.
  Head decals are kept. Face layout and dynamic-head skinning must be compatible.
- R15 keeps the existing MeshPart, joints, attachments, size and clothing.
  ApplyMesh also replaces LOCAL collision/mesh geometry. This is not a promise
  of identical physics with arbitrary shapes. Keep meshes close to native bounds.
- Layered 3D clothing requires compatible WrapTarget outer cages, WrapLayers
  and skinning. An arbitrary .mesh alone does not supply all avatar metadata.
  Existing cages are retained by default and may not fit a different shape.
  Provide matching cages below. This does not generate cages or bones.
- Custom cage properties have Plugin Security. They work only if your executor
  exposes those writes. Unsupported cage options are rejected before replacing
  the active setup; no thread-identity or property-security bypass is attempted.
- A retained SurfaceAppearance or R6 overlay can obscure classic clothing.
  R6 custom body meshes start without an overlay. R15 SurfaceAppearances are
  retained; prepare a compatible avatar asset if its shader covers clothing.

OPTIONAL config.json
Keys inside R6/R15 are body names; spaces/underscores are accepted as above.
An entry can be a filename string, an object below, or false to disable a part.
Files named in an entry must be directly inside its R6/R15 directory.
Paths, '..', URLs, OBJ/FBX and changing HumanoidRootPart are not supported.
No config or user asset is overwritten by this loader.

Example (replace the default config only if you have these files):
{
  "R6": {
    "Torso": { "mesh": "Torso.mesh", "texture": "skin.png" },
    "Head": { "mesh": "Head.mesh", "headScale": [1,1,1], "headOffset": [0,0,0] }
  },
  "R15": {
    "UpperTorso": {
      "mesh": "UpperTorso.mesh",
      "texture": "skin.png",
      "cage": "UpperTorso_cage.mesh",
      "cageOrigin": [0,0,0],
      "importOrigin": [0,0,0]
    }
  }
}
texture: optional PNG/JPG/JPEG base texture, not a shirt/pants asset ID.
         Omit to retain the existing R15 texture; R6 uses body color by default.
cage: optional native .mesh outer cage for a R15 MeshPart's WrapTarget.
cageOrigin/importOrigin: optional CFrame arrays of 3 position numbers or
         12 numbers [x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22].
         Use transforms from the correctly imported character in Studio.
headScale/headOffset: R6 SpecialMesh head only.

TROUBLESHOOTING
The console reports errors and the number of applied parts. Invalid JSON,
missing configured files and rejected imports preserve the current setup.
An unexpected application error rolls the character back to its original meshes.
If a game replaces body parts, the loader reapplies. If it overwrites geometry
in-place later, call Reload. Clothing property changes need no manual copying.
Executor implementations vary: filesystem + getcustomasset must support meshes,
and the Roblox client must accept their local asset URIs. No API/security bypass
is attempted. Report the console error if your executor rejects the file type.
Unique _cache files prevent stale geometry after Reload; only this run's own
files are removed when delfile exists. If not, clear _cache after leaving Roblox.
The script was checked for Lua syntax and simulated lifecycle behavior;
live Roblox rendering and executor compatibility still require an in-game test.
]]

for _, path in ipairs({ROOT, ROOT .. "/R6", ROOT .. "/R15", ROOT .. "/_cache"}) do
    if not FS.isfolder(path) then FS.makefolder(path) end
end
if not FS.isfile(ROOT .. "/config.json") then FS.writefile(ROOT .. "/config.json", DEFAULT_CONFIG) end
if not FS.isfile(ROOT .. "/README.txt") then FS.writefile(ROOT .. "/README.txt", README) end
if not FS.isfile(ROOT .. "/avatar_items.json") then FS.writefile(ROOT .. "/avatar_items.json", DEFAULT_ITEMS) end
if not FS.isfile(ROOT .. "/AVATAR_ITEMS.txt") then FS.writefile(ROOT .. "/AVATAR_ITEMS.txt", AVATAR_HELP) end

local previous = env.LocalCharacterMeshes
if type(previous) == "table" and previous.Version == VERSION and previous.Folder == ROOT
    and type(previous.Reload) == "function" and type(previous.Stop) == "function" then
    previous.Reload()
    return previous
end
if type(previous) == "table" and type(previous.Stop) == "function" then previous.Stop() end

local names = {
    R6 = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"},
    R15 = {"Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand",
        "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg",
        "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"},
}
local function normalize(s) return (s:lower():gsub("[ _%-]", "")) end
local function log(message) print("[LocalCharacterMeshes] " .. message) end
local function report(message) warn("[LocalCharacterMeshes] " .. tostring(message)) end
local function destroy(object) if object then pcall(function() object:Destroy() end) end end
local function clone(object)
    local old = object.Archivable
    object.Archivable = true
    local ok, result = pcall(function() return object:Clone() end)
    object.Archivable = old
    if not ok or not result then error("Cannot back up " .. object.Name) end
    return result
end
local function numbers(value, count, label)
    if type(value) ~= "table" or #value ~= count then error(label .. " needs " .. count .. " numbers") end
    for _, n in ipairs(value) do
        if type(n) ~= "number" or n ~= n or math.abs(n) > 100000 then error("Invalid " .. label) end
    end
    return value
end
local function vector(value, label, positive)
    if value == nil then return nil end
    numbers(value, 3, label)
    if positive then for _, n in ipairs(value) do if n <= 0 then error(label .. " must be positive") end end end
    return Vector3.new(value[1], value[2], value[3])
end
local function frame(value, label)
    if value == nil then return nil end
    numbers(value, type(value) == "table" and #value == 12 and 12 or 3, label)
    return CFrame.new(table.unpack(value))
end

local controller = {Folder = ROOT, Version = VERSION, Status = "starting"}
local running, generation, counter, queued = true, 0, 0, false
local session = Http:GenerateGUID(false):gsub("[^%w]", "")
local records, activeFiles, connections, characterConnections = {}, {}, {}, {}
local watchedCharacter
local activeProxy, releaseProxy
env.LocalCharacterMeshes = controller

local function deleteFiles(files)
    if type(FS.delete) == "function" then
        for _, path in ipairs(files) do pcall(FS.delete, path) end
    end
end
local function disposePrepared(prepared, removeFiles)
    for _, object in ipairs(prepared.objects) do destroy(object) end
    for _, r in ipairs(prepared.previewRecords or {}) do
        destroy(r.backup)
        for _, object in ipairs(r.originals or {}) do destroy(object) end
    end
    destroy(prepared.visualModel)
    if removeFiles then deleteFiles(prepared.files) end
end
local function restoreRecords(items)
    for i = #items, 1, -1 do
        local r = items[i]
        local ok, err = pcall(function()
            if r.kind == "meshpart" then
                -- Games can detach/reparent a surviving body part before replacing it.
                -- Its geometry is still ours to restore even outside the character.
                r.part:ApplyMesh(r.backup)
                if r.wrap then
                    if r.wrapBackup then
                        r.wrap.CageMeshId = r.wrapBackup.mesh
                        r.wrap.CageOrigin = r.wrapBackup.cageOrigin
                        r.wrap.ImportOrigin = r.wrapBackup.importOrigin
                    else destroy(r.wrap) end
                end
            else
                destroy(r.created)
                for _, object in ipairs(r.originals) do
                    if object.Parent == nil then object.Parent = r.parent end
                end
            end
        end)
        if not ok then report("Restore failed: " .. tostring(err)) end
        destroy(r.backup)
    end
end
local function restoreActive()
    restoreRecords(records)
    records = {}
    deleteFiles(activeFiles)
    activeFiles = {}
    if activeProxy then releaseProxy(activeProxy); activeProxy = nil end
    controller.VisualCharacter = nil
end
local function disconnect(items)
    for _, connection in ipairs(items) do connection:Disconnect() end
end

local function pathFor(rig, file, meshFile)
    if type(file) ~= "string" or file == "" or file:find("[/\\:%c]") or file:find("..", 1, true) then
        error("Use a filename directly inside " .. ROOT .. "/" .. rig .. ", not a path or URL")
    end
    local ext = file:lower():match("%.([%w]+)$")
    if meshFile and ext ~= "mesh" then error(file .. ": only native Roblox .mesh files are supported") end
    if not meshFile and ext ~= "png" and ext ~= "jpg" and ext ~= "jpeg" then error(file .. ": expected PNG/JPG/JPEG") end
    local path = ROOT .. "/" .. rig .. "/" .. file
    if not FS.isfile(path) then error("Missing file: " .. path) end
    return path, ext
end
local function snapshotAsset(prepared, rig, file, meshFile)
    local path, ext = pathFor(rig, file, meshFile)
    local bytes = FS.readfile(path)
    if #bytes == 0 or #bytes > 64 * 1024 * 1024 then error("Empty or oversized asset: " .. path) end
    if meshFile and not bytes:sub(1, 32):match("^version%s+%d+%.%d+") then
        error(path .. ": not a native Roblox .mesh file; renaming OBJ/FBX does not convert it")
    end
    counter = counter + 1
    local staged = ROOT .. "/_cache/" .. session .. "_" .. counter .. "." .. ext
    prepared.files[#prepared.files + 1] = staged
    FS.writefile(staged, bytes)
    local uri = FS.asset(staged)
    if type(uri) ~= "string" or uri == "" then error("getcustomasset rejected " .. path) end
    return uri
end
local function automaticFiles(rig)
    local result = {}
    for _, path in ipairs(FS.listfiles(ROOT .. "/" .. rig)) do
        local file = path:gsub("\\", "/"):match("([^/]+)$")
        if file and file:lower():match("%.mesh$") then
            local key = normalize(file:sub(1, -6))
            if result[key] then error("Duplicate mesh names: " .. result[key] .. " and " .. file) end
            result[key] = file
        end
    end
    return result
end
local validFields = {mesh=true, texture=true, cage=true, cageOrigin=true, importOrigin=true, headScale=true, headOffset=true}
local function overrides(config, rig)
    if config[rig] == nil then return {} end
    if type(config[rig]) ~= "table" then error(rig .. " in config.json must be an object") end
    local allowed, result = {}, {}
    for _, name in ipairs(names[rig]) do allowed[normalize(name)] = true end
    for name, spec in pairs(config[rig]) do
        if type(name) ~= "string" or not allowed[normalize(name)] then error("Unsupported " .. rig .. " body name: " .. tostring(name)) end
        local key = normalize(name)
        if result[key] ~= nil then error("Duplicate config entries for " .. name) end
        if type(spec) == "string" then spec = {mesh = spec} end
        if spec ~= false then
            if type(spec) ~= "table" then error(name .. " must be a filename, an object, or false") end
            for field in pairs(spec) do if not validFields[field] then error("Unknown option: " .. tostring(field)) end end
        end
        result[key] = spec
    end
    return result
end

local function prepare(prepared, character, rig, config, token, owner)
    owner = owner or character
    local automatic, custom = automaticFiles(rig), overrides(config, rig)
    for _, name in ipairs(names[rig]) do
        if not running or token ~= generation or owner ~= player.Character then error("Load cancelled") end
        local key = normalize(name)
        local spec = custom[key]
        if spec == nil then spec = {} end
        local file = spec ~= false and (spec.mesh or automatic[key])
        if spec ~= false and custom[key] ~= nil and not file then error("No mesh file configured for " .. name) end
        if file then
            local part = character:FindFirstChild(name)
            if part and part:IsA("BasePart") then
                local entry = {part=part, name=name}
                entry.uri = snapshotAsset(prepared, rig, file, true)
                entry.source = Assets:CreateMeshPartAsync(Content.fromUri(entry.uri), {
                    CollisionFidelity = part:IsA("MeshPart") and part.CollisionFidelity or Enum.CollisionFidelity.Box,
                    RenderFidelity = Enum.RenderFidelity.Precise,
                })
                if not entry.source or not entry.source:IsA("MeshPart") then error("Mesh import returned no MeshPart for " .. file) end
                prepared.objects[#prepared.objects + 1] = entry.source
                if spec.texture then entry.texture = snapshotAsset(prepared, rig, spec.texture, false) end
                if part:IsA("MeshPart") then
                    entry.kind = "meshpart"
                    if spec.cage then entry.cage = snapshotAsset(prepared, rig, spec.cage, true) end
                    entry.cageOrigin = frame(spec.cageOrigin, "cageOrigin")
                    entry.importOrigin = frame(spec.importOrigin, "importOrigin")
                    if (entry.cageOrigin or entry.importOrigin) and not entry.cage then error("Cage transforms require a cage file") end
                    if entry.cage then
                        local cageSource = Assets:CreateMeshPartAsync(Content.fromUri(entry.cage), {
                            CollisionFidelity = Enum.CollisionFidelity.Box,
                        })
                        if not cageSource or not cageSource:IsA("MeshPart") then error("Could not load cage for " .. name) end
                        prepared.objects[#prepared.objects + 1] = cageSource
                        local originalWrap = part:FindFirstChildOfClass("WrapTarget")
                        local cageProbe = originalWrap and clone(originalWrap) or Instance.new("WrapTarget")
                        prepared.objects[#prepared.objects + 1] = cageProbe
                        local cageOK, cageError = pcall(function()
                            -- Reads and writes must both be available for restoration.
                            local priorCage, priorOrigin, priorImport = cageProbe.CageMeshId, cageProbe.CageOrigin, cageProbe.ImportOrigin
                            cageProbe.CageMeshId = entry.cage
                            cageProbe.CageOrigin = entry.cageOrigin or priorOrigin
                            cageProbe.ImportOrigin = entry.importOrigin or priorImport
                        end)
                        if not cageOK then error("Custom cages require accessible WrapTarget properties: " .. tostring(cageError)) end
                    end
                    -- Check the native operation on a detached clone before altering the character.
                    local probe = clone(part)
                    prepared.objects[#prepared.objects + 1] = probe
                    probe:ApplyMesh(entry.source)
                elseif rig == "R6" and name == "Head" then
                    entry.kind = "head"
                    entry.created = Instance.new("SpecialMesh")
                    prepared.objects[#prepared.objects + 1] = entry.created
                    entry.created.MeshType = Enum.MeshType.FileMesh
                    entry.created.MeshId = entry.uri
                    entry.created.Scale = vector(spec.headScale, "headScale", true) or Vector3.new(1,1,1)
                    entry.created.Offset = vector(spec.headOffset, "headOffset") or Vector3.new(0,0,0)
                    if entry.texture then entry.created.TextureId = entry.texture end
                elseif rig == "R6" then
                    entry.kind = "r6"
                    entry.created = Instance.new("CharacterMesh")
                    prepared.objects[#prepared.objects + 1] = entry.created
                    entry.created.BodyPart = Enum.BodyPart[name:gsub(" ", "")]
                    local ok, err = pcall(function()
                        entry.created.MeshContent = Content.fromUri(entry.uri)
                        entry.created.OverlayTextureContent = Content.none
                        if entry.texture then entry.created.BaseTextureContent = Content.fromUri(entry.texture) end
                    end)
                    if not ok then error("R6 requires writable CharacterMesh.MeshContent on this client: " .. tostring(err)) end
                else
                    error(name .. " is not a MeshPart; custom non-standard R15 rigs need proper avatar assets")
                end
                if entry.kind ~= "meshpart" and (spec.cage or spec.cageOrigin or spec.importOrigin) then error("cage options require a MeshPart body part") end
                if entry.kind ~= "head" and (spec.headScale or spec.headOffset) then error("headScale/headOffset only apply to an R6 Part head") end
                prepared.entries[#prepared.entries + 1] = entry
            elseif custom[key] ~= nil then
                report("Body part not present yet: " .. name)
            end
        end
    end
end

local function applyEntry(character, entry, destination)
    destination = destination or records
    local part = entry.part
    if part.Parent ~= character then error("Body part replaced while loading: " .. entry.name) end
    local r = {kind=entry.kind, part=part, character=character}
    if entry.kind == "meshpart" then
        r.backup = clone(part)
        r.backup:ClearAllChildren()
        destination[#destination + 1] = r
        local size, texture = part.Size, part.TextureID
        local okContent, textureContent = pcall(function() return part.TextureContent end)
        part:ApplyMesh(entry.source)
        part.Size = size
        if entry.texture then part.TextureID = entry.texture
        elseif okContent and textureContent ~= nil then part.TextureContent = textureContent
        else part.TextureID = texture end
        if entry.cage then
            r.wrap = part:FindFirstChildOfClass("WrapTarget")
            if r.wrap then
                r.wrapBackup = {mesh=r.wrap.CageMeshId, cageOrigin=r.wrap.CageOrigin, importOrigin=r.wrap.ImportOrigin}
            else
                r.wrap = Instance.new("WrapTarget")
                r.wrap.Parent = part
            end
            r.wrap.CageMeshId = entry.cage
            if entry.cageOrigin then r.wrap.CageOrigin = entry.cageOrigin end
            if entry.importOrigin then r.wrap.ImportOrigin = entry.importOrigin end
        end
    else
        r.created, r.originals = entry.created, {}
        r.parent = entry.kind == "r6" and character or part
        destination[#destination + 1] = r
        for _, object in ipairs(r.parent:GetChildren()) do
            local matched = entry.kind == "r6" and object:IsA("CharacterMesh") and object.BodyPart == entry.created.BodyPart
            if entry.kind == "head" then matched = object:IsA("DataModelMesh") end
            if matched then r.originals[#r.originals + 1] = object; object.Parent = nil end
        end
        entry.created.Name = "__LocalCharacterMeshes_" .. entry.name
        entry.created.Parent = r.parent
    end
end

local slots = {[2]="GraphicTShirt", [11]="Shirt", [12]="Pants", [17]="Head", [18]="Face",
    [27]="Torso", [28]="RightArm", [29]="LeftArm", [30]="LeftLeg", [31]="RightLeg", [79]="Head"}
local accessoryTypes = {[8]="Hat", [41]="Hair", [42]="Face", [43]="Neck", [44]="Shoulder",
    [45]="Front", [46]="Back", [47]="Waist", [57]="Face", [58]="Face",
    [64]="TShirt", [65]="Shirt", [66]="Pants", [67]="Jacket", [68]="Sweater",
    [69]="Shorts", [70]="LeftShoe", [71]="RightShoe", [72]="DressSkirt", [76]="Eyebrow", [77]="Eyelash"}
local function assetID(value)
    local id = tonumber(value)
    if not id or id ~= id or id <= 0 or id > 9007199254740991 or id % 1 ~= 0 then
        error("Expected a positive integer catalog ID")
    end
    return id
end
local function selection(value)
    if type(value) ~= "table" then error("avatar_items.json must be an object") end
    for key in pairs(value) do if key ~= "assets" and key ~= "bundles" then error("Unknown item list: " .. tostring(key)) end end
    local result = {assets={}, bundles={}}
    for _, kind in ipairs({"assets", "bundles"}) do
        local items, seen = value[kind] or {}, {}
        if type(items) ~= "table" or #items > 128 then error(kind .. " must be an array with at most 128 IDs") end
        for key in pairs(items) do
            if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #items then error(kind .. " must be a JSON array") end
        end
        for _, valueID in ipairs(items) do
            local id = assetID(valueID)
            if not seen[id] then seen[id] = true; result[kind][#result[kind] + 1] = id end
        end
    end
    return result
end
local function readItems() return selection(Http:JSONDecode(FS.readfile(ROOT .. "/avatar_items.json"))) end
local function checkLoad(token, character)
    if not running or token ~= generation or player.Character ~= character then error("Load cancelled") end
end
local function makeAvatar(prepared, character, humanoid, rig, items, token)
    prepared.itemSlots = {}
    local description = humanoid:GetAppliedDescription()
    prepared.objects[#prepared.objects + 1] = description
    local accessories = description:GetAccessories(true)
    local seen, order = {}, 0
    for _, item in ipairs(accessories) do
        seen[item.AssetId] = true
        order = math.max(order, item.Order or 0)
    end
    local function add(id, skipUnsupported)
        checkLoad(token, character)
        local info = Marketplace:GetProductInfoAsync(id, Enum.InfoType.Asset)
        checkLoad(token, character)
        local assetType = tonumber(info.AssetTypeId)
        local slot, accessory = slots[assetType], accessoryTypes[assetType]
        if slot then description[slot] = id; prepared.itemSlots[slot] = true
        elseif accessory then
            if not seen[id] then
                local layered = (assetType >= 64 and assetType <= 72) or assetType == 76 or assetType == 77
                local item = {AssetId=id, AccessoryType=Enum.AccessoryType[accessory], IsLayered=layered}
                if layered then order = order + 1; item.Order = order end
                accessories[#accessories + 1] = item
                seen[id] = true
            end
        elseif skipUnsupported then return false
        else error("Asset " .. id .. " is not a supported wearable (AssetTypeId " .. tostring(assetType) .. ")") end
        return true
    end
    for _, id in ipairs(items.bundles) do
        checkLoad(token, character)
        local details = Assets:GetBundleDetailsAsync(id)
        checkLoad(token, character)
        local count = 0
        for _, item in ipairs(details.Items or {}) do
            if item.Type == "Asset" and add(assetID(item.Id), true) then count = count + 1 end
        end
        if count == 0 then error("Bundle " .. id .. " contains no supported wearables") end
    end
    -- Explicit assets override body/clothing slots supplied by bundles.
    for _, id in ipairs(items.assets) do add(id, false) end
    description:SetAccessories(accessories, true)
    checkLoad(token, character)
    local model = Players:CreateHumanoidModelFromDescriptionAsync(description,
        rig == "R6" and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15, Enum.AssetTypeVerification.Always)
    prepared.visualModel = model
    checkLoad(token, character)
    if not model or not model:IsA("Model") or not model:FindFirstChild("HumanoidRootPart") then
        error("Roblox did not create a standard R6/R15 visual avatar")
    end
    local loaded = 0
    for _, object in ipairs(model:GetChildren()) do if object:IsA("Accessory") then loaded = loaded + 1 end end
    if loaded < #accessories then error("Roblox omitted one or more accessories; an item may be unavailable or incompatible") end
    for _, object in ipairs(model:GetDescendants()) do
        if object:IsA("Script") or object:IsA("LocalScript") or object:IsA("ModuleScript") then destroy(object) end
    end
    model.Name = "__LocalCharacterMeshes_" .. session
    return model
end

local function jointKey(joint)
    return joint.Part0.Name .. "\0" .. joint.Part1.Name
end
local clothingFields = {{"Shirt", "ShirtTemplate", "Shirt"}, {"Pants", "PantsTemplate", "Pants"},
    {"ShirtGraphic", "Graphic", "GraphicTShirt"}}
local function proxyState(model, character, itemSlots)
    local root = model:FindFirstChild("HumanoidRootPart")
    local realRoot = character:FindFirstChild("HumanoidRootPart")
    if not realRoot or not realRoot:IsA("BasePart") then error("Your character has no HumanoidRootPart") end
    local state = {model=model, character=character, root=root, realRoot=realRoot, parts={}, edges={}, loose={},
        originals={}, joints={}, bones={}, decals={}, itemSlots=itemSlots, bind="LocalCharacterMeshes_" .. session, live=false}
    local actualBones = {}
    for _, object in ipairs(character:GetDescendants()) do
        if object:IsA("Motor6D") and object.Part0 and object.Part1 then state.joints[jointKey(object)] = object end
        if object:IsA("Bone") then
            local part = object.Parent
            while part and part ~= character and not part:IsA("BasePart") do part = part.Parent end
            if part and part:IsA("BasePart") then actualBones[part.Name .. "\0" .. object.Name] = object end
        end
    end
    local unresolved = {}
    for _, object in ipairs(model:GetDescendants()) do
        if object:IsA("BasePart") then
            object.Anchored, object.CanCollide, object.CanTouch, object.CanQuery = true, false, false, false
            state.parts[#state.parts + 1] = object
        elseif object:IsA("Decal") then
            state.decals[#state.decals + 1] = {object=object, transparency=object.Transparency}
        elseif (object:IsA("Motor6D") or object:IsA("Weld") or object:IsA("WeldConstraint"))
            and object.Part0 and object.Part1 and object.Part0:IsDescendantOf(model) and object.Part1:IsDescendantOf(model) then
            unresolved[#unresolved + 1] = {joint=object, p0=object.Part0, p1=object.Part1,
                motor=object:IsA("Motor6D"), constraint=object:IsA("WeldConstraint")}
        elseif object:IsA("Bone") then
            local part = object.Parent
            while part and part ~= model and not part:IsA("BasePart") do part = part.Parent end
            local source = part and actualBones[part.Name .. "\0" .. object.Name]
            if source then state.bones[#state.bones + 1] = {target=object, source=source} end
        end
    end
    local known = {[root]=true}
    while #unresolved > 0 do
        local progress = false
        for i = #unresolved, 1, -1 do
            local edge = unresolved[i]
            if known[edge.p0] or known[edge.p1] then
                table.remove(unresolved, i)
                if not (known[edge.p0] and known[edge.p1]) then
                    edge.reverse = known[edge.p1] == true
                    edge.offset = edge.p0.CFrame:Inverse() * edge.p1.CFrame
                    if edge.motor then edge.source = state.joints[jointKey(edge.joint)] end
                    state.edges[#state.edges + 1] = edge
                    known[edge.p0], known[edge.p1], progress = true, true, true
                end
            end
        end
        if not progress then break end
    end
    for _, part in ipairs(state.parts) do
        if not known[part] then state.loose[#state.loose + 1] = {part=part, offset=root.CFrame:Inverse() * part.CFrame} end
    end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.AutoRotate = false
        humanoid.AutomaticScalingEnabled = false
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end
    root.Transparency = 1
    return state
end
releaseProxy = function(state)
    state.live = false
    pcall(function() RunService:UnbindFromRenderStep(state.bind) end)
    for object, original in pairs(state.originals) do
        pcall(function() object[original.property] = original.value end)
    end
    destroy(state.model)
end
local function startProxy(state)
    local character = state.character
    state.live = true
    local function draw()
        if not state.live or not running or player.Character ~= character or not state.realRoot.Parent then return end
        state.root.CFrame = state.realRoot.CFrame
        for _, edge in ipairs(state.edges) do
            local transform = edge.source and edge.source.Parent and edge.source.Transform or CFrame.new()
            local relative = edge.constraint and edge.offset or edge.joint.C0 * transform * edge.joint.C1:Inverse()
            if edge.reverse then edge.p0.CFrame = edge.p1.CFrame * relative:Inverse()
            else edge.p1.CFrame = edge.p0.CFrame * relative end
        end
        for _, loose in ipairs(state.loose) do loose.part.CFrame = state.root.CFrame * loose.offset end
        for _, bone in ipairs(state.bones) do if bone.source.Parent then bone.target.Transform = bone.source.Transform end end
        -- Preserve live classic clothing unless that slot was explicitly requested by ID.
        for _, field in ipairs(clothingFields) do
            if not state.itemSlots[field[3]] then
                local source = character:FindFirstChildOfClass(field[1])
                local target = state.model:FindFirstChildOfClass(field[1])
                if source then
                    if not target then target = Instance.new(field[1]); target.Parent = state.model end
                    target[field[2]] = source[field[2]]
                elseif target then destroy(target) end
            end
        end
        -- Keep equipped Tool handles visible. Remember originals only after the old proxy is released.
        for _, object in ipairs(character:GetChildren()) do
            local hide = {}
            if object:IsA("BasePart") then
                hide[1] = object
                for _, decal in ipairs(object:GetDescendants()) do if decal:IsA("Decal") then hide[#hide + 1] = decal end end
            elseif object:IsA("Accessory") then
                for _, part in ipairs(object:GetDescendants()) do
                    if part:IsA("BasePart") or part:IsA("Decal") then hide[#hide + 1] = part end
                end
            end
            for _, part in ipairs(hide) do
                local property = part:IsA("BasePart") and "LocalTransparencyModifier" or "Transparency"
                if state.originals[part] == nil then state.originals[part] = {property=property, value=part[property]} end
                -- A game may update a decal while hidden; preserve its latest visible value.
                if property == "Transparency" and part[property] ~= 1 then state.originals[part].value = part[property] end
                part[property] = 1
            end
        end
        local camera = workspace.CurrentCamera
        local firstPerson = camera and (camera.CFrame.Position - camera.Focus.Position).Magnitude < 1
        for _, part in ipairs(state.parts) do part.LocalTransparencyModifier = firstPerson and 1 or 0 end
        for _, decal in ipairs(state.decals) do decal.object.Transparency = firstPerson and 1 or decal.transparency end
    end
    draw()
    state.model.Parent = workspace
    RunService:BindToRenderStep(state.bind, Enum.RenderPriority.Last.Value, draw)
end

local currentItems
function controller.Reload(candidate)
    if not running then return false end
    generation = generation + 1
    local token, character = generation, player.Character
    if not character then controller.Status = "waiting for character"; return false end
    local prepared = {entries={}, objects={}, files={}}
    local items, state, serialized, previousItems
    local ok, err = pcall(function()
        local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
        if not humanoid or not humanoid:IsA("Humanoid") then error("No Humanoid in your character") end
        local rig = humanoid.RigType == Enum.HumanoidRigType.R6 and "R6" or "R15"
        local config = Http:JSONDecode(FS.readfile(ROOT .. "/config.json"))
        if type(config) ~= "table" then error("config.json must be an object") end
        items = candidate and selection(candidate) or readItems()
        local target = character
        if #items.assets + #items.bundles > 0 then
            target = makeAvatar(prepared, character, humanoid, rig, items, token)
        end
        prepare(prepared, target, rig, config, token, character)
        checkLoad(token, character)
        if target ~= character then
            prepared.previewRecords = {}
            for _, entry in ipairs(prepared.entries) do applyEntry(target, entry, prepared.previewRecords) end
            state = proxyState(target, character, prepared.itemSlots)
        end
        if candidate then
            serialized = Http:JSONEncode(items)
            previousItems = FS.readfile(ROOT .. "/avatar_items.json")
            FS.writefile(ROOT .. "/avatar_items.json", serialized)
        end
    end)
    if not ok or not running or token ~= generation or character ~= player.Character then
        disposePrepared(prepared, true)
        if running and token == generation then controller.Status = "load failed"; report(err or "Load cancelled") end
        return false
    end
    restoreActive()
    activeFiles = prepared.files
    ok, err = pcall(function()
        if state then
            records, activeProxy = prepared.previewRecords, state
            startProxy(state)
            controller.VisualCharacter = state.model
        else
            for _, entry in ipairs(prepared.entries) do applyEntry(character, entry) end
        end
    end)
    if not ok then
        restoreActive()
        prepared.visualModel, prepared.previewRecords = nil, nil
        disposePrepared(prepared, true)
        if serialized then pcall(FS.writefile, ROOT .. "/avatar_items.json", previousItems) end
        controller.Status = "application failed"
        report("Rolled back to original meshes: " .. tostring(err))
        return false
    end
    currentItems = items
    -- Sources/probes can be destroyed after ApplyMesh; installed native nodes stay alive.
    local installed = {}
    for _, r in ipairs(records) do if r.created then installed[r.created] = true end end
    for _, object in ipairs(prepared.objects) do if not installed[object] then destroy(object) end end
    controller.Status = "applied " .. #prepared.entries .. " mesh part(s), " .. (#items.assets + #items.bundles) .. " catalog selection(s)"
    log(controller.Status .. "; folder: " .. ROOT .. ". Clothing requires matching Roblox UVs/cages.")
    if #prepared.entries == 0 and not state then log("Add .mesh files to R6/R15, or call Wear(catalogAssetID).") end
    return true
end

function controller.ListItems() return selection(currentItems or readItems()) end
local function changeItems(kind, value, remove)
    if not running then return false end
    local ok, result = pcall(function()
        local id, items = assetID(value), selection(currentItems or readItems())
        local found = false
        for i = #items[kind], 1, -1 do
            if items[kind][i] == id then found = true; if remove then table.remove(items[kind], i) end end
        end
        if not found and not remove then items[kind][#items[kind] + 1] = id end
        return controller.Reload(items)
    end)
    if not ok then report(result); return false end
    return result
end
function controller.Wear(id) return changeItems("assets", id, false) end
function controller.WearBundle(id) return changeItems("bundles", id, false) end
function controller.Remove(id) return changeItems("assets", id, true) end
function controller.RemoveBundle(id) return changeItems("bundles", id, true) end
function controller.ClearItems() return controller.Reload({assets={}, bundles={}}) end

function controller.Stop()
    if not running then return end
    running, generation = false, generation + 1
    disconnect(connections)
    disconnect(characterConnections)
    restoreActive()
    controller.Status = "stopped"
    if env.LocalCharacterMeshes == controller then env.LocalCharacterMeshes = nil end
    log("Stopped; original meshes restored where the character still exists.")
end

local function schedule()
    if not running or queued == generation then return end
    local scheduledGeneration = generation
    queued = scheduledGeneration
    task.delay(0.2, function()
        if queued == scheduledGeneration then queued = false end
        if running and generation == scheduledGeneration then controller.Reload() end
    end)
end
local function watchCharacter(character)
    generation = generation + 1
    disconnect(characterConnections)
    characterConnections = {}
    restoreActive()
    watchedCharacter = character
    if character then
        characterConnections[#characterConnections + 1] = character.ChildAdded:Connect(function(object)
            if object:IsA("BasePart") or object:IsA("Humanoid") then schedule() end
        end)
        schedule()
    end
end
connections[#connections + 1] = player.CharacterAdded:Connect(watchCharacter)
connections[#connections + 1] = player.CharacterRemoving:Connect(function(character)
    if character == watchedCharacter then watchCharacter(nil) end
end)
connections[#connections + 1] = player.CharacterAppearanceLoaded:Connect(function(character)
    if character == player.Character then schedule() end
end)
watchCharacter(player.Character)
return controller
