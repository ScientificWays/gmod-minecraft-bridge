---- Minecraft Bridge
---- Server autorun logic

if game.SinglePlayer()--[[ or not string.StartWith(game.GetMap(), "mb_")--]] then

	return
end

local MapBuildOffsetZ = 0

function InitializeMapBuildOffsetZ(InPlayer)
	MapBuildOffsetZ = GetGlobalOffsetZ() * GetMinecraftBlockSizeInv()
	MsgN(Format("MapBuildOffsetZ: %i", MapBuildOffsetZ))
end

local MapChunksX = 1
local MapChunksY = 1

local MapChunkSize = 4
local MapChunkSizeZ = 16

--[[timer.Create("HUDHintDataTick", 0.2, 0, function()

	ResetHUDHintData()

	local ClientPlayer = LocalPlayer()

	if not IsValid(ClientPlayer) or ClientPlayer:GetNWFloat("TaskTimeLeft") > 0.0 then

		return
	end

	UpdatePostProcessData(ClientPlayer)

	local ClientWeapon = ClientPlayer:GetActiveWeapon()

	if not IsValid(ClientWeapon) or ClientWeapon:GetClass() ~= "weapon_rpp_unarmed" or not UtilPlayerCanInteract(ClientPlayer) then

		return
	end

	local EyeTrace = ClientPlayer:GetEyeTrace()

	if EyeTrace.Fraction * 32768 > 128 or not IsValid(EyeTrace.Entity) then

		return
	end

	--MsgN(EyeTrace.Entity:GetCollisionGroup())

	UpdateHUDHintData(ClientPlayer, EyeTrace.Entity)
end)--]]

function MinecraftSendMapData()

	InitializeMapBuildOffsetZ()

	local ChunkID = 0

	for x = -MapChunksX, MapChunksX do

		for y = -MapChunksY, MapChunksY do

			MinecraftMapSendChunk(ChunkID, x, y)
			ChunkID = ChunkID + 1
			--return
		end
	end
end

function MinecraftMapSendChunk(InID, InOffsetX, InOffsetY)

	local OutTable = { ID = InID, points = {} }
	local OccludedCoords = {}

	local BlockCenterOffset = Vector(0.5, -0.5, 0.5) * GetMinecraftBlockSize()

	local BoundsStart = { x = -MapChunkSize + InOffsetX * MapChunkSize, y = -MapChunkSize + InOffsetY * MapChunkSize, z = -MapChunkSizeZ * 0.5 + MapBuildOffsetZ }
	local BoundsEnd = { x = MapChunkSize + InOffsetX * MapChunkSize, y = MapChunkSize + InOffsetY * MapChunkSize, z = MapChunkSizeZ * 1.5 + MapBuildOffsetZ}

	for x = BoundsStart.x, BoundsEnd.x do
		for y = BoundsStart.y, BoundsEnd.y do
			for z = BoundsStart.z, BoundsEnd.z do
				local TraceLocation = Vector(x, y, z) * GetMinecraftBlockSize() + BlockCenterOffset

				local TraceResult = util.TraceLine({
					start = TraceLocation + Vector(0.0, 0.55, 0.55) * GetMinecraftBlockSize(),
					endpos = TraceLocation,
					mask = CONTENTS_SOLID})

				if TraceResult.HitTexture == "**empty**" then
					TraceResult = util.TraceLine({
					start = TraceLocation - Vector(0.0, 0.55, 0.55) * GetMinecraftBlockSize(),
					endpos = TraceLocation,
					mask = CONTENTS_SOLID})
				end
				--MsgN(Format("HitWorld: %s", TraceResult.HitWorld))

				if TraceResult.HitWorld and TraceResult.MatType ~= MAT_DEFAULT then

					--debugoverlay.Box(TraceLocation, Vector(1,1,1) * -16, Vector(1,1,1) * 16, 100)

					if OccludedCoords[x] == nil then
						OccludedCoords[x] = {}
					end

					if OccludedCoords[x][y] == nil then
						OccludedCoords[x][y] = {}
					end
					OccludedCoords[x][y][z] = GetMinecraftMaterialIndex(TraceResult.HitTexture)
					--MsgN(Format("Index: %s", OccludedCoords[x][y][z]))
					--PrintTable(TraceResult)
					--MsgN(Format("HitTexture: %s", TraceResult.HitTexture))

					if OccludedCoords[x][y][z] > 0 then
						--debugoverlay.Box(TraceLocation, Vector(1,1,1) * -16, Vector(1,1,1) * 16, 100)
					end
				end
			end
		end
	end

	--PrintTable(OccludedCoords)

	for x = BoundsStart.x, BoundsEnd.x do
		for y = BoundsStart.y, BoundsEnd.y do
			for z = BoundsStart.z, BoundsEnd.z do
				if OccludedCoords[x] and OccludedCoords[x][y] and OccludedCoords[x][y][z] then

					if OccludedCoords[x + 1] and OccludedCoords[x + 1][y] and OccludedCoords[x + 1][y][z]
				and OccludedCoords[x - 1] and OccludedCoords[x - 1][y] and OccludedCoords[x - 1][y][z]
				and OccludedCoords[x] and OccludedCoords[x][y + 1] and OccludedCoords[x][y + 1][z]
				--[[and OccludedCoords[x] --]]and OccludedCoords[x][y - 1] and OccludedCoords[x][y - 1][z]
				--[[and OccludedCoords[x] --]]and OccludedCoords[x][y] and OccludedCoords[x][y][z + 1]
				--[[and OccludedCoords[x] and OccludedCoords[x][y] --]]and OccludedCoords[x][y][z - 1] then

					else
						local BlockLocation = Vector(x, y, z) * GetMinecraftBlockSize()
						--debugoverlay.Box(BlockLocation, Vector(1,1,1) * -16, Vector(1,1,1) * 16, 100)

						table.insert(OutTable.points, BlockLocation.X)
						table.insert(OutTable.points, BlockLocation.Z)
						table.insert(OutTable.points, -BlockLocation.Y)
						table.insert(OutTable.points, OccludedCoords[x][y][z])
					end
				end
			end
		end
	end

	local OutJSON = util.TableToJSON(OutTable)

	--print(OutJSON)

	local OutRequest = {
		url			= GetMinecraftPostGmodMapURL(),
		method		= "post",
		body		= OutJSON,
		type		= "application/json",

		--Parameters
		--OutTable,

		--Success Callback
		success = OnMinecraftInitMapSuccess,

		--Failure Callback
		failed = OnMinecraftInitMapFailure
	}
	HTTP(OutRequest)
end

local function OnMinecraftInitMapSuccess(InCode, InBody, InHeaders)

	MsgN(Format("OnMinecraftInitMapSuccess() body: %s", InBody))


end

local function OnMinecraftInitMapFailure(InError)

	MsgN(Format("OnMinecraftInitMapFailure() error: %s", InError))


end
