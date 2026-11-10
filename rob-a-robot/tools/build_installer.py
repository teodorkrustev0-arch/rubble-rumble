#!/usr/bin/env python3
"""Builds Installer.lua from the files in src/.

Installer.lua is one script you paste into the Roblox Studio Command Bar.
It creates every Script / ModuleScript in the right place for you.

Run from the rob-a-robot folder:   python3 tools/build_installer.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

# (file, Roblox class, service, folder inside the service or None, name)
FILES = [
    ("ReplicatedStorage/Shared/Config.luau", "ModuleScript", "ReplicatedStorage", "Shared", "Config"),
    ("ReplicatedStorage/Shared/PartCatalog.luau", "ModuleScript", "ReplicatedStorage", "Shared", "PartCatalog"),
    ("ServerScriptService/Main.server.luau", "Script", "ServerScriptService", None, "Main"),
]
for name in ["Net", "Util", "ItemVisuals", "PlayerData", "MapBuilder", "BaseService", "RobotService",
             "ConveyorService", "StealService", "ShopService", "GuardService", "EventService", "DataService"]:
    FILES.append((f"ServerScriptService/Services/{name}.luau", "ModuleScript", "ServerScriptService", "Services", name))
FILES.append(("StarterPlayerScripts/ClientMain.client.luau", "LocalScript", "StarterPlayerScripts", None, "ClientMain"))

OPEN, CLOSE = "[=====[", "]=====]"

out = [
    "-- Rob-a-Robot installer. GENERATED FILE - edit the files in src/ instead.",
    "-- Paste this whole file into the Roblox Studio Command Bar and press Enter.",
    "local function container(serviceName, folderName)",
    "\tlocal parent = serviceName == 'StarterPlayerScripts'",
    "\t\tand game:GetService('StarterPlayer'):WaitForChild('StarterPlayerScripts')",
    "\t\tor game:GetService(serviceName)",
    "\tif not folderName then return parent end",
    "\tlocal folder = parent:FindFirstChild(folderName)",
    "\tif not folder then",
    "\t\tfolder = Instance.new('Folder')",
    "\t\tfolder.Name = folderName",
    "\t\tfolder.Parent = parent",
    "\tend",
    "\treturn folder",
    "end",
    "local function install(className, serviceName, folderName, name, source)",
    "\tlocal parent = container(serviceName, folderName)",
    "\tlocal old = parent:FindFirstChild(name)",
    "\tif old then old:Destroy() end",
    "\tlocal script = Instance.new(className)",
    "\tscript.Name = name",
    "\tscript.Source = source",
    "\tscript.Parent = parent",
    "end",
]
for rel, cls, service, folder, name in FILES:
    source = (SRC / rel).read_text(encoding="utf-8")
    assert OPEN not in source and CLOSE not in source, rel
    folder_arg = f"'{folder}'" if folder else "nil"
    # The newline right after the opening bracket is skipped by Lua.
    out.append(f"install('{cls}', '{service}', {folder_arg}, '{name}', {OPEN}\n{source}{CLOSE})")
out.append(f"print('Rob-a-Robot: installed {len(FILES)} scripts. Press Play!')")

(ROOT / "Installer.lua").write_text("\n".join(out) + "\n", encoding="utf-8")
print(f"Wrote Installer.lua with {len(FILES)} scripts")
