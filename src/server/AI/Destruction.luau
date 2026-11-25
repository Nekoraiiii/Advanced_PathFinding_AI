--!strict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-414758D0FBB491857603

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Settings = require(script.Parent.Settings)
local random = Random.new()
local active: { Folder } = {}
local GROUP = "NoobWallDebris"

local function isBreakable(part: Instance): boolean
	return part:IsA("Part")
		and part.Shape == Enum.PartType.Block
		and part.Anchored
		and part.CanCollide
		and part:IsDescendantOf(Workspace)
		and CollectionService:HasTag(part, "Breakable")
		and part:GetAttribute("Breakable") ~= false
end

local function shatter(wall: BasePart, direction: Vector3): boolean
	if not isBreakable(wall) then
		return false
	end

	local size, cf = wall.Size, wall.CFrame
	local step = math.max(0.5, Settings.FragmentSize)
	local cap = math.max(1, math.min(Settings.MaxFragments, Settings.GlobalFragmentLimit))
	local nx, ny, nz = 1, 1, 1

	repeat
		nx, ny, nz =
			math.max(1, math.ceil(size.X / step)),
			math.max(1, math.ceil(size.Y / step)),
			math.max(1, math.ceil(size.Z / step))
		step *= 1.25
	-- Copyright (c) 2026 ZakirGG | APFAI-414758D0FBB491857603/01 | Proprietary source.
	until nx * ny * nz <= cap

	local count = nx * ny * nz
	local cell = Vector3.new(size.X / nx, size.Y / ny, size.Z / nz)
	local folder = Instance.new("Folder")
	folder.Name = "WallFragments"

	local ok, err = pcall(function()
		for x = 1, nx do
			for y = 1, ny do
				for z = 1, nz do
					local part = Instance.new("Part")
					part.Name = "Fragment"
					part.Parent = folder
					part.Size = cell * 0.94
					part.CFrame = cf
						* CFrame.new(
							-size / 2 + Vector3.new((x - 0.5) * cell.X, (y - 0.5) * cell.Y, (z - 0.5) * cell.Z)
						)
					part.Color = wall.Color
					part.Material = wall.Material
					part.MaterialVariant = wall.MaterialVariant
					part.Transparency = wall.Transparency
					part.Reflectance = wall.Reflectance
					part.Anchored = true
					part.CanCollide = true
					part.CanTouch = false
					part.CollisionGroup = GROUP

					local modifier = Instance.new("PathfindingModifier")
					modifier.PassThrough = true
					modifier.Parent = part
				end
			end
		end
	end)

	if not ok then
		folder:Destroy()
		warn("[APFAI 1.0 Destruction]", err)
		return false
	end

	for i = #active, 1, -1 do
		if not active[i].Parent then
			table.remove(active, i)
		end
	end

	local total = count

	for _, old in active do
		total += #old:GetChildren()
	end

	while total > Settings.GlobalFragmentLimit and #active > 0 do
		local old = table.remove(active, 1)
		total -= #old:GetChildren()
		old:Destroy()
	end
	-- Copyright (c) 2026 ZakirGG | APFAI-414758D0FBB491857603/02 | Proprietary source.
	-- The NPC ignores the debris collision group, while the floor and players still collide.
	folder.Parent = Workspace
	table.insert(active, folder)
	Debris:AddItem(folder, Settings.DebrisLifetime)
	wall:Destroy()

	for _, instance in folder:GetChildren() do
		if instance:IsA("BasePart") then
			instance.Anchored = false
			local part = instance
			local physicsOK, physicsError = pcall(function()
				if part:CanSetNetworkOwnership() then
					part:SetNetworkOwner(nil)
				end

				local velocity = direction * random:NextNumber(12, 26)
					+ Vector3.new(random:NextNumber(-8, 8), random:NextNumber(4, 15), random:NextNumber(-8, 8))
				part:ApplyImpulse(velocity * part.AssemblyMass)
				part:ApplyAngularImpulse(
					Vector3.new(random:NextNumber(-5, 5), random:NextNumber(-5, 5), random:NextNumber(-5, 5))
						* part.AssemblyMass
				)
			end)

			if not physicsOK then
				warn("[APFAI 1.0 fragment]", physicsError)
			end
		end
	end
	return true
end
return { isBreakable = isBreakable, shatter = shatter }
