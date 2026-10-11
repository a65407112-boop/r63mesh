-- Local Character Meshes v1.2: native GUI, folder packs, GitHub preset installer.
-- Client-only appearance changes to Players.LocalPlayer.Character.
-- Requires executor filesystem APIs and getcustomasset with .mesh support.
-- Catalog metadata/model requests use Roblox's public APIs.
-- No global asset replacement or changes to other players' characters.
-- R15 ApplyMesh also updates LOCAL collision geometry; it is not shader-only.

local ROOT = "LocalCharacterMeshes"
local VERSION = "1.2.0"
local PACKS = ROOT .. "/Packs"
local PRESET = "RBLXBikiniMod"
local PRESET_URL = "https://raw.githubusercontent.com/a65407112-boop/r63mesh/dcce8db9d4341aea4b78b0d4379b4a9f4959d6e4/LocalCharacterMeshes/R6/"
local PRESET_FILES = {{"Torso.mesh",1787881},{"LeftArm.mesh",6089},{"RightArm.mesh",6089},
    {"LeftLeg.mesh",341425},{"RightLeg.mesh",341425}}
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
local PACK_HELP = [[НАБОРЫ МЕШЕЙ — GUI v1.2

Создай в workspace своего executor папку:
LocalCharacterMeshes/Packs/ЛюбоеНазвание
Положи туда нативные Roblox .mesh с именами частей тела.
В GUI открой селектор наборов или нажми обновление, выбери папку и нажми Применить.
Папки R6/R15 внутри набора тоже поддерживаются; они имеют приоритет над файлами
в корне набора для соответствующего рига. Можно использовать пробелы и Unicode.

R6: Head.mesh, Torso.mesh, LeftArm.mesh, RightArm.mesh, LeftLeg.mesh, RightLeg.mesh.
R15: Head.mesh, UpperTorso.mesh, LowerTorso.mesh, LeftUpperArm.mesh, LeftLowerArm.mesh,
LeftHand.mesh, RightUpperArm.mesh, RightLowerArm.mesh, RightHand.mesh,
LeftUpperLeg.mesh, LeftLowerLeg.mesh, LeftFoot.mesh, RightUpperLeg.mesh,
RightLowerLeg.mesh, RightFoot.mesh.
Пробелы, подчёркивания, дефисы и регистр имён файлов игнорируются при сопоставлении.
Выбор сохраняется в selected_pack.txt и применяется после респавна.
Старые LocalCharacterMeshes/R6 и /R15 доступны как «Мои меши (R6 / R15)».

RBLXBikiniMod автоматически скачивается с GitHub в Packs/RBLXBikiniMod.
Это пять оригинальных R6-мешей; пользовательские файлы не заменяются.
Кнопка GitHub добавляет недостающие файлы. Нужны HTTP и delfile для отката записи.

Необязательный config.json находится в папке набора и использует ключи R6/R15.
Файлы в нём указываются относительно выбранной папки рига или корня набора.
Подробные параметры текстур и cages описаны в README.txt.
Одежде нужны совместимые Roblox UV/cages: скрипт не создаёт их.

GUI: ID предмета/набора, удаление, обновление, отключение мешей, восстановление.
RightShift скрывает/показывает окно; после сворачивания нажми кнопку R63.
Перетаскивай заголовок мышью или касанием. Stop восстанавливает исходный аватар.
]]
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
2. Put NATIVE ROBLOX .mesh files in LocalCharacterMeshes/Packs/<YourName>.
   Open the GUI mesh selector, choose your folder and click Apply.
   R6/R15 subfolders inside each pack are supported. See PACKS.txt.
   Files live inside your EXECUTOR workspace directory, not Roblox Workspace.
   The original LocalCharacterMeshes/R6 and /R15 folders still work.
3. To reread changed files, use the GUI Reload button or run:
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

local selectionWasNew = not FS.isfile(ROOT .. "/selected_pack.txt")
for _, path in ipairs({ROOT, ROOT .. "/R6", ROOT .. "/R15", ROOT .. "/_cache", PACKS}) do
    if not FS.isfolder(path) then FS.makefolder(path) end
end
if not FS.isfile(ROOT .. "/config.json") then FS.writefile(ROOT .. "/config.json", DEFAULT_CONFIG) end
if not FS.isfile(ROOT .. "/README.txt") then FS.writefile(ROOT .. "/README.txt", README) end
if not FS.isfile(ROOT .. "/avatar_items.json") then FS.writefile(ROOT .. "/avatar_items.json", DEFAULT_ITEMS) end
if not FS.isfile(ROOT .. "/AVATAR_ITEMS.txt") then FS.writefile(ROOT .. "/AVATAR_ITEMS.txt", AVATAR_HELP) end
if not FS.isfile(ROOT .. "/PACKS.txt") then FS.writefile(ROOT .. "/PACKS.txt", PACK_HELP) end
if selectionWasNew then FS.writefile(ROOT .. "/selected_pack.txt", "") end

local previous = env.LocalCharacterMeshes
if type(previous) == "table" and previous.Version == VERSION and previous.Folder == ROOT
    and type(previous.Reload) == "function" and type(previous.Stop) == "function" then
    if type(previous.ShowUI) == "function" and env.LocalCharacterMeshesGUI ~= false then previous.ShowUI() end
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

local controller = {Folder = ROOT, Version = VERSION, Status = "starting", MeshesEnabled = true}
local running, generation, counter, queued = true, 0, 0, false
local session = Http:GenerateGUID(false):gsub("[^%w]", "")
local records, activeFiles, connections, characterConnections = {}, {}, {}, {}
local watchedCharacter
local activeProxy, releaseProxy
local ui, refreshUI, destroyUI
local installGeneration, packGeneration = 0, 0
local uiGeneration, settingOwners = 0, {}
env.LocalCharacterMeshes = controller
local function setStatus(value, err)
    controller.Status, controller.LastError = value, err and tostring(err) or nil
    if refreshUI then refreshUI() end
end

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

local function pathFor(rig, file, meshFile, sourceRoot)
    sourceRoot = sourceRoot or ROOT .. "/" .. rig
    if type(file) ~= "string" or file == "" or file:find("[/\\:%c]") or file:find("..", 1, true) then
        error("Use a filename directly inside " .. sourceRoot .. ", not a path or URL")
    end
    local ext = file:lower():match("%.([%w]+)$")
    if meshFile and ext ~= "mesh" then error(file .. ": only native Roblox .mesh files are supported") end
    if not meshFile and ext ~= "png" and ext ~= "jpg" and ext ~= "jpeg" then error(file .. ": expected PNG/JPG/JPEG") end
    local path = sourceRoot .. "/" .. file
    if not FS.isfile(path) then error("Missing file: " .. path) end
    return path, ext
end
local function snapshotAsset(prepared, rig, file, meshFile, sourceRoot)
    local path, ext = pathFor(rig, file, meshFile, sourceRoot)
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
local function automaticFiles(rig, sourceRoot)
    local result = {}
    for _, path in ipairs(FS.listfiles(sourceRoot or ROOT .. "/" .. rig)) do
        local file = path:gsub("\\", "/"):match("([^/]+)$")
        if file and file:lower():match("%.mesh$") then
            local key = normalize(file:sub(1, -6))
            if result[key] then error("Duplicate mesh names: " .. result[key] .. " and " .. file) end
            result[key] = file
        end
    end
    return result
end
local function packName(value)
    if value == nil or value == "" then return nil end
    if type(value) ~= "string" or value == "." or value == ".." or value:find("[/\\:%c]") then
        error("Use an existing folder name from " .. PACKS)
    end
    return value
end
local function meshSource(rig, chosenPack)
    local base, configPath
    if chosenPack then
        base = PACKS .. "/" .. packName(chosenPack)
        if not FS.isfolder(base) then error("Mesh pack folder not found: " .. chosenPack) end
        configPath = base .. "/config.json"
        if FS.isfolder(base .. "/" .. rig) then base = base .. "/" .. rig end
    else base, configPath = ROOT .. "/" .. rig, ROOT .. "/config.json" end
    local config = FS.isfile(configPath) and Http:JSONDecode(FS.readfile(configPath)) or {R6={}, R15={}}
    if type(config) ~= "table" then error("config.json must be an object") end
    return base, config
end
do
    local saved = FS.readfile(ROOT .. "/selected_pack.txt")
    local ok, name = pcall(packName, saved)
    if ok then controller.SelectedPack = name else report(name) end
end
function controller.ListPacks()
    local result, seen = {{Id="", Name="Мои меши (R6 / R15)"}}, {}
    for _, path in ipairs(FS.listfiles(PACKS)) do
        local name = path:gsub("\\", "/"):gsub("/$", ""):match("([^/]+)$")
        if name and not seen[name] and FS.isfolder(PACKS .. "/" .. name) then
            local ok = pcall(packName, name)
            if ok then result[#result + 1] = {Id=name, Name=name}; seen[name] = true end
        end
    end
    table.sort(result, function(a,b) if a.Id == "" then return b.Id ~= "" end;if b.Id == "" then return false end;return a.Name:lower() < b.Name:lower() end)
    return result
end
function controller.InstallPack()
    if not running then return false end
    installGeneration = installGeneration + 1
    local token, downloaded, written = installGeneration, {}, {}
    local folder = PACKS .. "/" .. PRESET
    local function check() if not running or token ~= installGeneration then error("Installation cancelled") end end
    local ok, err = pcall(function()
        if not FS.isfolder(folder) then FS.makefolder(folder) end
        local existing = automaticFiles("R6", folder)
        for _, file in ipairs(PRESET_FILES) do
            local key = normalize(file[1]:sub(1,-6))
            if not existing[key] then
                if type(FS.delete) ~= "function" then error("Preset installation requires delfile for rollback") end
                check()
                local bytes = game:HttpGet(PRESET_URL .. file[1])
                check()
                if type(bytes) ~= "string" or #bytes ~= file[2] or not bytes:sub(1,32):match("^version%s+%d+%.%d+") then
                    error("GitHub returned an invalid mesh: " .. file[1])
                end
                downloaded[#downloaded + 1] = {name=file[1], key=key, bytes=bytes}
            end
        end
        check()
        existing = automaticFiles("R6", folder)
        for _, file in ipairs(downloaded) do
            check()
            if not existing[file.key] then
                local path = folder .. "/" .. file.name
                written[#written + 1] = {path=path, bytes=file.bytes}
                FS.writefile(path, file.bytes)
                check()
                if FS.readfile(path) ~= file.bytes then error("Executor did not preserve binary mesh bytes: " .. file.name) end
                existing[file.key] = file.name
            end
        end
    end)
    if not ok then
        for _, file in ipairs(written) do pcall(function() if FS.isfile(file.path) then FS.delete(file.path) end end) end
        controller.InstallError = tostring(err)
        report(err)
        return false
    end
    controller.InstallError = nil
    log("Preset ready: " .. PRESET .. "; existing files retained.")
    if refreshUI then refreshUI() end
    return true
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

local function prepare(prepared, character, rig, config, token, owner, sourceRoot)
    owner = owner or character
    local automatic, custom = automaticFiles(rig, sourceRoot), overrides(config, rig)
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
                entry.uri = snapshotAsset(prepared, rig, file, true, sourceRoot)
                entry.source = Assets:CreateMeshPartAsync(Content.fromUri(entry.uri), {
                    CollisionFidelity = part:IsA("MeshPart") and part.CollisionFidelity or Enum.CollisionFidelity.Box,
                    RenderFidelity = Enum.RenderFidelity.Precise,
                })
                if not entry.source or not entry.source:IsA("MeshPart") then error("Mesh import returned no MeshPart for " .. file) end
                prepared.objects[#prepared.objects + 1] = entry.source
                if spec.texture then entry.texture = snapshotAsset(prepared, rig, spec.texture, false, sourceRoot) end
                if part:IsA("MeshPart") then
                    entry.kind = "meshpart"
                    if spec.cage then entry.cage = snapshotAsset(prepared, rig, spec.cage, true, sourceRoot) end
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
function controller.Reload(candidate, candidatePack, savePack, candidateEnabled)
    if not running then return false end
    generation = generation + 1
    local token, character = generation, player.Character
    if not character then setStatus("waiting for character"); return false end
    local prepared = {entries={}, objects={}, files={}}
    local items, state, chosenPack, validation
    local meshesEnabled = controller.MeshesEnabled
    if candidateEnabled ~= nil then meshesEnabled = candidateEnabled end
    local savedFiles = {}
    local function writeSetting(path, bytes)
        local file = {path=path, original=FS.readfile(path), bytes=bytes}
        savedFiles[#savedFiles + 1] = file
        settingOwners[path] = file
        FS.writefile(path, bytes)
        file.complete = true
    end
    local function rollbackSettings()
        for i=#savedFiles,1,-1 do
            local file = savedFiles[i]
            pcall(function()
                if settingOwners[file.path] == file and (not file.complete or FS.readfile(file.path) == file.bytes) then
                    FS.writefile(file.path, file.original)
                    settingOwners[file.path] = nil
                end
            end)
        end
    end
    local ok, err = pcall(function()
        local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
        if not humanoid or not humanoid:IsA("Humanoid") then error("No Humanoid in your character") end
        local rig = humanoid.RigType == Enum.HumanoidRigType.R6 and "R6" or "R15"
        if savePack then chosenPack = packName(candidatePack) else chosenPack = controller.SelectedPack end
        local sourceRoot, config
        if meshesEnabled or savePack then sourceRoot, config = meshSource(rig, chosenPack) end
        items = candidate and selection(candidate) or readItems()
        local target = character
        if #items.assets + #items.bundles > 0 then
            target = makeAvatar(prepared, character, humanoid, rig, items, token)
        end
        if meshesEnabled or savePack then
            local meshPrepared = prepared
            if not meshesEnabled then validation = {entries={},objects={},files={}};meshPrepared = validation end
            prepare(meshPrepared, target, rig, config, token, character, sourceRoot)
            if chosenPack and #meshPrepared.entries == 0 then error("Pack " .. chosenPack .. " has no compatible mesh parts for " .. rig) end
            if validation then disposePrepared(validation, true);validation = nil end
        end
        checkLoad(token, character)
        if target ~= character then
            prepared.previewRecords = {}
            for _, entry in ipairs(prepared.entries) do applyEntry(target, entry, prepared.previewRecords) end
            state = proxyState(target, character, prepared.itemSlots)
        end
        if candidate then
            writeSetting(ROOT .. "/avatar_items.json", Http:JSONEncode(items))
        end
        if savePack then writeSetting(ROOT .. "/selected_pack.txt", chosenPack or "") end
        checkLoad(token, character)
    end)
    if not ok or not running or token ~= generation or character ~= player.Character then
        if validation then disposePrepared(validation, true) end
        disposePrepared(prepared, true)
        rollbackSettings()
        if running and token == generation then setStatus("load failed", err or "Load cancelled"); report(err or "Load cancelled") end
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
        rollbackSettings()
        setStatus("application failed", err)
        report("Rolled back to original meshes: " .. tostring(err))
        return false
    end
    currentItems = items
    controller.SelectedPack = chosenPack
    controller.MeshesEnabled = meshesEnabled
    -- Sources/probes can be destroyed after ApplyMesh; installed native nodes stay alive.
    local installed = {}
    for _, r in ipairs(records) do if r.created then installed[r.created] = true end end
    for _, object in ipairs(prepared.objects) do if not installed[object] then destroy(object) end end
    setStatus("applied " .. #prepared.entries .. " mesh part(s), " .. (#items.assets + #items.bundles) .. " catalog selection(s)")
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
    if not ok then setStatus("load failed", result); report(result); return false end
    return result
end
function controller.Wear(id) return changeItems("assets", id, false) end
function controller.WearBundle(id) return changeItems("bundles", id, false) end
function controller.Remove(id) return changeItems("assets", id, true) end
function controller.RemoveBundle(id) return changeItems("bundles", id, true) end
function controller.ClearItems() return controller.Reload({assets={}, bundles={}}) end
function controller.SelectPack(value)
    local ok, name = pcall(packName, value)
    if not ok then setStatus("load failed", name); report(name); return false end
    packGeneration = packGeneration + 1
    return controller.Reload(nil, name, true)
end
function controller.SetMeshesEnabled(value)
    if type(value) ~= "boolean" or not running then return false end
    return controller.Reload(nil, nil, false, value)
end

function controller.Stop()
    if not running then return end
    running, generation = false, generation + 1
    installGeneration = installGeneration + 1
    disconnect(connections)
    disconnect(characterConnections)
    restoreActive()
    controller.Status = "stopped"
    if destroyUI then destroyUI() end
    if env.LocalCharacterMeshes == controller then env.LocalCharacterMeshes = nil end
    log("Stopped; original meshes restored where the character still exists.")
end

-- Native UI; no external GUI library or downloaded executable code.
local function buildUI(token)
    local Input = game:GetService("UserInputService")
    local parent
    if type(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok then parent = result end
    end
    parent = parent or player:WaitForChild("PlayerGui", 5)
    if not running or token ~= uiGeneration then return false end
    if not parent then error("PlayerGui is not available yet") end
    local theme = {background=Color3.fromRGB(15,19,29), card=Color3.fromRGB(25,32,46),
        accent=Color3.fromRGB(110,239,185), text=Color3.fromRGB(239,244,250),
        muted=Color3.fromRGB(155,168,188), danger=Color3.fromRGB(255,134,148)}
    local state = {connections={}, rows={}, rowConnections={}, packRows={}, packConnections={},
        buttons={}, busy=false, pendingPack=controller.SelectedPack or "", message="", width=420, height=670}
    ui = state
    local function make(class, name, parentObject, properties)
        local object = Instance.new(class)
        object.Name = name
        for key, value in pairs(properties or {}) do object[key] = value end
        object.Parent = parentObject
        return object
    end
    local function round(object, radius)
        make("UICorner", "Corners", object, {CornerRadius=UDim.new(0,radius or 9)})
    end
    local function connect(signal, callback, list)
        local c = signal:Connect(callback)
        local destination = list or state.connections
        destination[#destination + 1] = c
        return c
    end
    local function label(name, text, x, y, w, h, size, color, parentObject)
        return make("TextLabel", name, parentObject or state.panel, {Text=text, Position=UDim2.new(0,x,0,y),
            Size=UDim2.new(0,w,0,h), BackgroundTransparency=1, TextColor3=color or theme.text,
            TextSize=size or 14, Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Left,
            TextYAlignment=Enum.TextYAlignment.Center, BorderSizePixel=0})
    end
    local function button(name, text, x, y, w, h, accent, parentObject, passive)
        local b = make("TextButton", name, parentObject or state.panel, {Text=text,
            Position=UDim2.new(0,x,0,y), Size=UDim2.new(0,w,0,h), BorderSizePixel=0,
            BackgroundColor3=accent and theme.accent or theme.card, AutoButtonColor=true,
            TextColor3=accent and theme.background or theme.text, TextSize=13,
            Font=Enum.Font.GothamMedium, Active=true})
        round(b)
        if not passive then state.buttons[#state.buttons + 1] = {object=b, accent=accent} end
        return b
    end
    state.root = make("ScreenGui", "__R63MeshUI", nil, {ResetOnSpawn=false,
        DisplayOrder=80, IgnoreGuiInset=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
    controller.Gui = state.root
    state.panel = make("Frame", "MainPanel", state.root, {Size=UDim2.new(0,420,0,670),
        Position=UDim2.new(0,0,0,0), BackgroundColor3=theme.background,
        BorderSizePixel=0, Active=true, ClipsDescendants=true})
    round(state.panel,14)
    make("UIStroke", "Outline", state.panel, {Color=theme.muted, Thickness=1, Transparency=0.7})
    state.scale = make("UIScale", "ViewportScale", state.panel, {Scale=1})
    local header = make("Frame", "DragHandle", state.panel, {Size=UDim2.new(1,-48,0,64),
        BackgroundTransparency=1, BorderSizePixel=0, Active=true})
    local title = label("Title", "R63 MESH",18,14,260,28,22,nil,header)
    title.Font = Enum.Font.GothamBold
    state.subtitle = label("Subtitle", "Локальный аватар",18,43,320,16,11,theme.muted,header)
    local minimize = button("Minimize","—",376,16,26,28,false,nil,true)
    state.launcher = button("OpenPanel","R63",12,110,58,42,true,state.root,true)
    state.launcher.Visible = false

    label("PacksTitle", "НАБОРЫ МЕШЕЙ",18,78,260,20,12,theme.muted)
    state.packChoice = button("PackSelector","Выбери папку",18,104,264,38,false)
    local packRefresh = button("RefreshPacks","Обновить",292,104,110,38,false)
    local applyPack = button("ApplyPack","Применить набор",18,152,242,34,true)
    local installPack = button("InstallPack","Набор GitHub",270,152,132,34,false)
    local hint = label("FolderHint","Папки: LocalCharacterMeshes/Packs/<название>",18,193,384,30,11,theme.muted)
    hint.TextWrapped = true
    label("ItemsTitle","ПРЕДМЕТЫ ПО ID",18,234,300,20,12,theme.muted)
    state.idInput = make("TextBox", "AssetIdInput", state.panel, {Position=UDim2.new(0,18,0,260),
        Size=UDim2.new(0,384,0,38), BackgroundColor3=theme.card, BorderSizePixel=0,
        Text="", PlaceholderText="ID или ссылка Roblox", PlaceholderColor3=theme.muted,
        TextColor3=theme.text, Font=Enum.Font.Gotham, TextSize=15, ClearTextOnFocus=false})
    round(state.idInput)
    local wearAsset = button("WearAsset","Надеть предмет",18,310,184,34,true)
    local wearBundle = button("WearBundle","Надеть набор ID",218,310,184,34,false)
    label("CurrentItemsTitle","Ваши предметы",18,364,270,22,14)
    local clear = button("ClearItems","Очистить",300,364,102,25,false)
    state.itemsList = make("ScrollingFrame", "CurrentItems", state.panel, {Position=UDim2.new(0,18,0,394),
        Size=UDim2.new(0,384,0,110), CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3, ScrollBarImageColor3=theme.muted})
    make("UIListLayout", "Layout", state.itemsList, {Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder})
    state.meshToggle = button("ToggleMeshes","Меши: включены",18,520,184,34,false)
    local reload = button("Reload","Перезагрузить",218,520,184,34,false)
    local stop = button("Stop","Восстановить аватар и выйти",18,568,384,34,false,nil,true)
    stop.TextColor3 = theme.danger
    state.status = label("Status","Подготовка…",18,615,384,42,12,theme.muted)
    state.status.TextWrapped, state.status.TextYAlignment = true, Enum.TextYAlignment.Top

    state.packMenu = make("ScrollingFrame", "PackMenu", state.panel, {Position=UDim2.new(0,18,0,146),
        Size=UDim2.new(0,384,0,176), BackgroundColor3=theme.card, BorderSizePixel=0, Visible=false,
        CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollBarThickness=4,
        ScrollBarImageColor3=theme.accent, ZIndex=20})
    round(state.packMenu)
    make("UIListLayout", "Layout", state.packMenu, {Padding=UDim.new(0,3), SortOrder=Enum.SortOrder.LayoutOrder})
    local function alive() return running and ui == state and state.root.Parent ~= nil end
    local function resetRows(rows, connectionsList)
        disconnect(connectionsList)
        for _, row in ipairs(rows) do destroy(row) end
    end
    local function setPanelVisible(visible)
        state.panel.Visible, state.launcher.Visible = visible, not visible
        state.packMenu.Visible = false
    end
    local function packs()
        resetRows(state.packRows,state.packConnections)
        state.packRows, state.packConnections = {}, {}
        local list = controller.ListPacks()
        for index, pack in ipairs(list) do
            local row = button("Pack_" .. pack.Id, pack.Name .. (pack.Id == PRESET and "  · R6" or ""),
                0,0,376,34,false,state.packMenu,true)
            row.ZIndex, row.LayoutOrder = 21, index
            row.TextXAlignment = Enum.TextXAlignment.Left
            state.packRows[#state.packRows + 1] = row
            connect(row.Activated, function()
                if not alive() or state.busy then return end
                state.pendingPack, state.hasPending = pack.Id, true
                state.packMenu.Visible = false
                refreshUI()
            end, state.packConnections)
        end
        return list
    end
    refreshUI = function()
        if not alive() then return end
        if not state.hasPending then state.pendingPack = controller.SelectedPack or "" end
        state.packChoice.Text = state.pendingPack == "" and "Мои меши (R6 / R15)" or state.pendingPack
        state.meshToggle.Text = controller.MeshesEnabled and "Меши: включены" or "Меши: выключены"
        local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        state.subtitle.Text = "Только для тебя  · " .. (h and (h.RigType == Enum.HumanoidRigType.R6 and "R6" or "R15") or "ждём персонажа")
        for _, item in ipairs(state.buttons) do
            item.object.Active, item.object.AutoButtonColor = not state.busy, not state.busy
            item.object.TextColor3 = state.busy and theme.muted or (item.accent and theme.background or theme.text)
        end
        local ok, items = pcall(controller.ListItems)
        if not ok then items = {assets={},bundles={}} end
        local key = table.concat(items.assets,",") .. "|" .. table.concat(items.bundles,",")
        if key ~= state.itemsKey then
            state.itemsKey = key
            resetRows(state.rows,state.rowConnections)
            state.rows, state.rowConnections = {}, {}
            local index = 0
            for _, kind in ipairs({"assets","bundles"}) do
                for _, id in ipairs(items[kind]) do
                    index = index + 1
                    local row = make("Frame", "ItemRow_" .. index, state.itemsList, {Size=UDim2.new(1,-8,0,42),
                        BackgroundColor3=theme.card, BorderSizePixel=0, LayoutOrder=index})
                    round(row,8)
                    state.rows[#state.rows + 1] = row
                    label("ItemName", (kind == "assets" and "Предмет  · " or "Набор ID  · ") .. id,
                        12,0,276,42,13,nil,row)
                    local remove = button((kind == "assets" and "RemoveAsset_" or "RemoveBundle_") .. id,
                        "×",326,6,36,30,false,row,true)
                    remove.TextColor3 = theme.danger
                    connect(remove.Activated, function()
                        state.Run(function() if kind == "assets" then return controller.Remove(id) else return controller.RemoveBundle(id) end end,
                            "Убираю предмет…")
                    end,state.rowConnections)
                end
            end
            if index == 0 then
                local empty = label("EmptyItems","Здесь появятся предметы, добавленные по ID.",8,8,358,42,12,theme.muted,state.itemsList)
                empty.TextWrapped = true
                state.rows[#state.rows + 1] = empty
            end
        end
        local message = state.message
        local failed = state.messageError
        if not state.busy and message == "" then
            if controller.LastError then message, failed = "Не удалось применить. Проверь ID, папку и риг. Подробности в консоли.", true
            elseif controller.Status == "waiting for character" then message = "Ждём появления персонажа…"
            elseif controller.Status == "starting" then message = "Подготовка…"
            else message = "Готово. Открой селектор, чтобы увидеть свои папки." end
        end
        state.status.Text, state.status.TextColor3 = message, failed and theme.danger or theme.muted
    end
    state.Run = function(action, pending)
        if not alive() or state.busy then return false end
        state.busy, state.message, state.messageError = true, pending or "Загрузка…", false
        state.packMenu.Visible = false
        refreshUI()
        task.spawn(function()
            local ok, result = pcall(action)
            if not alive() then return end
            state.busy = false
            if not ok or result == false then
                state.message, state.messageError = "Не удалось применить. Проверь ID, папку и риг. Подробности в консоли.", true
                if not ok then report(result) end
            else state.message, state.messageError = "Готово.", false end
            refreshUI()
        end)
        return true
    end
    local function inputID(text, kind)
        local value = text:match("^%s*(.-)%s*$")
        if value:match("^%d+$") then return assetID(value) end
        local host, path = value:match("^https?://([^/]+)(/.*)$")
        if host and (host:lower() == "roblox.com" or host:lower() == "www.roblox.com") then
            local id = path:match(kind == "assets" and "^/catalog/(%d+)" or "^/bundles/(%d+)")
            if id then return assetID(id) end
        end
        error("Введите ID или подходящую ссылку Roblox")
    end
    local function wear(kind)
        if state.busy then return end
        local ok, id = pcall(inputID, state.idInput.Text, kind)
        if not ok then
            state.message, state.messageError = "Введи числовой ID или ссылку Roblox на предмет / набор.", true
            refreshUI(); return
        end
        state.Run(function() if kind == "assets" then return controller.Wear(id) else return controller.WearBundle(id) end end,"Собираю аватар…")
    end
    connect(wearAsset.Activated,function() wear("assets") end)
    connect(wearBundle.Activated,function() wear("bundles") end)
    connect(clear.Activated,function() state.Run(controller.ClearItems,"Убираю предметы…") end)
    connect(reload.Activated,function() state.Run(controller.Reload,"Перечитываю меши…") end)
    connect(stop.Activated,controller.Stop)
    connect(state.meshToggle.Activated,function() state.Run(function() return controller.SetMeshesEnabled(not controller.MeshesEnabled) end,"Обновляю меши…") end)
    connect(applyPack.Activated,function()
        local name = state.pendingPack
        state.Run(function()
            local ok = controller.SelectPack(name)
            if ok then state.hasPending = false end
            return ok
        end,"Применяю выбранный набор…")
    end)
    connect(installPack.Activated,function()
        state.Run(function()
            if not controller.InstallPack() then return false end
            packs(); state.pendingPack, state.hasPending = PRESET, true
            local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if h and h.RigType == Enum.HumanoidRigType.R6 then
                local ok = controller.SelectPack(PRESET)
                if ok then state.hasPending = false end
                return ok
            end
            return true
        end,"Скачиваю R6-набор с GitHub…")
    end)
    connect(state.packChoice.Activated,function()
        if state.busy then return end
        if state.packMenu.Visible then state.packMenu.Visible = false
        else local ok,err=pcall(packs);if ok then state.packMenu.Visible=true else report(err) end end
    end)
    connect(packRefresh.Activated,function()
        if state.busy then return end
        local ok,err=pcall(packs)
        if ok then state.message,state.messageError="Список папок обновлён.",false else report(err) end
        refreshUI()
    end)
    connect(minimize.Activated,function() setPanelVisible(false) end)
    connect(state.launcher.Activated,function() setPanelVisible(true) end)
    connect(Input.InputBegan,function(input,processed)
        if alive() and not processed and input.KeyCode == Enum.KeyCode.RightShift and not Input:GetFocusedTextBox() then
            setPanelVisible(not state.panel.Visible)
        end
    end)
    local function clampPosition(x,y)
        x = math.max(0,math.min(x,math.max(0,state.viewWidth-420*state.scale.Scale)))
        y = math.max(0,math.min(y,math.max(0,state.viewHeight-670*state.scale.Scale)))
        state.panel.Position = UDim2.new(0,x,0,y)
    end
    local function fit()
        local camera = workspace.CurrentCamera
        local view = camera and camera.ViewportSize or Vector2.new(1280,720)
        state.viewWidth,state.viewHeight = view.X,math.max(1,view.Y-72)
        state.scale.Scale = math.max(0.1,math.min(1,(view.X-16)/420,state.viewHeight/670))
        if state.moved then clampPosition(state.panel.Position.X.Offset,state.panel.Position.Y.Offset)
        else clampPosition((state.viewWidth-420*state.scale.Scale)/2,(state.viewHeight-670*state.scale.Scale)/2) end
    end
    local cameraConnection
    local function bindCamera()
        if cameraConnection then cameraConnection:Disconnect() end
        local camera = workspace.CurrentCamera
        if camera then cameraConnection = connect(camera:GetPropertyChangedSignal("ViewportSize"),fit) end
        fit()
    end
    connect(workspace:GetPropertyChangedSignal("CurrentCamera"),bindCamera)
    connect(header.InputBegan,function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            state.dragInput,state.dragStart,state.dragX,state.dragY = input,input.Position,state.panel.Position.X.Offset,state.panel.Position.Y.Offset
            state.packMenu.Visible = false
        end
    end)
    connect(Input.InputChanged,function(input)
        if not alive() or not state.panel.Visible or not state.dragStart then return end
        if input == state.dragInput or (state.dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - state.dragStart
            state.moved = true
            clampPosition(state.dragX+delta.X,state.dragY+delta.Y)
        end
    end)
    connect(Input.InputEnded,function(input)
        if input == state.dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then state.dragStart,state.dragInput=nil,nil end
    end)
    if not running or token ~= uiGeneration then
        disconnect(state.connections);disconnect(state.rowConnections);disconnect(state.packConnections);destroy(state.root)
        return false
    end
    state.root.Parent = parent
    bindCamera()
    refreshUI()
    return state.root
end
destroyUI = function()
    uiGeneration = uiGeneration + 1
    if not ui then return end
    disconnect(ui.connections); disconnect(ui.rowConnections); disconnect(ui.packConnections)
    destroy(ui.root)
    ui, refreshUI, controller.Gui = nil, nil, nil
end
function controller.ShowUI()
    if not running then return false end
    if ui and ui.root.Parent then
        ui.panel.Visible,ui.launcher.Visible=true,false
        refreshUI()
        return ui.root
    end
    if ui then destroyUI() end
    uiGeneration = uiGeneration + 1
    local token = uiGeneration
    local ok, result = pcall(buildUI, token)
    if not ok then
        if token == uiGeneration then destroyUI();report("GUI could not start: " .. tostring(result)) end
        return false
    end
    return result
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
if env.LocalCharacterMeshesGUI ~= false then controller.ShowUI() end
if env.LocalCharacterMeshesAutoInstall ~= false then
    local initialPackGeneration = packGeneration
    local function bootstrap()
        if not controller.InstallPack() or not running then return false end
        if selectionWasNew and packGeneration == initialPackGeneration and not controller.SelectedPack then
            local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if h and h.RigType == Enum.HumanoidRigType.R6 then
                local ok,config = pcall(Http.JSONDecode,Http,FS.readfile(ROOT .. "/config.json"))
                local configured = ok and type(config) == "table" and type(config.R6) == "table" and next(config.R6) ~= nil
                if not configured and next(automaticFiles("R6")) == nil then return controller.SelectPack(PRESET) end
            end
        end
        return controller.Reload()
    end
    if ui then ui.Run(bootstrap,"Скачиваю R6-набор с GitHub…")
    else task.defer(function() local ok,err=pcall(bootstrap);if not ok then report(err) end end) end
end
return controller
