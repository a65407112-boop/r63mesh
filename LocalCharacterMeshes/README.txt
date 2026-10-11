LOCAL CHARACTER MESHES

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
