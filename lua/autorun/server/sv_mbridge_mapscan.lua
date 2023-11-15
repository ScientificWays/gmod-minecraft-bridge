---- Minecraft Bridge
---- Garry's mod map scan

if game.SinglePlayer()--[[ or not string.StartWith(game.GetMap(), "mb_")--]] then

	return
end

local MinecraftMaterialKeyWords = {
	["concrete"] = 1,
	["grass"] = 2,
	["brick"] = 3,
	["plaster"] = 4,
	["building"] = 5,
	["roof"] = 6,
	["wood"] = 7,
	["cliff"] = 8,
	["stone"] = 9
}

function GetMinecraftMaterialKeyWords()
	return MinecraftMaterialKeyWords
end

function GetMinecraftMaterialIndex(InTextureName)

	if InTextureName == "**displacement**" then
		return MinecraftMaterialKeyWords["grass"]
	end
	local LowercaseName = string.lower(InTextureName)

	local LastWordStart = 1
	local LastWordIndex = 0

	for SampleKeyWord, SampleIndex in pairs(MinecraftMaterialKeyWords) do

		local Start, End = string.find(LowercaseName, SampleKeyWord, LastWordStart)

		if Start ~= nil then

			LastWordStart = Start
			LastWordIndex = SampleIndex
		end
	end

	return LastWordIndex
end

local MapChunkBoundsMin = Vector(-4, -4, -2)
local MapChunkBoundsMax = Vector(4, 4, 4)

local MapChunkSize = 8

local MapChunkSizeUnitsMin = Vector(-1.0, -1.0, -1.0)
local MapChunkSizeUnitsMax = Vector(1.0, 1.0, 1.0)

local TraceStartOffset = Vector(0.0, 0.0, 0.0)

function GetMinecraftTraceStartOffset()
	return TraceStartOffset
end

--timer.Create("TraceStartOffsetff", 1.0, 0, function() MsgN(TraceStartOffset) end)

function MinecraftUpdateMapScanData()
	local Size = MapChunkSize * GetMinecraftBlockSize()
	MapChunkSizeUnitsMin = -Vector(Size, Size, Size)
	MapChunkSizeUnitsMax = Vector(Size, Size, Size)
	TraceStartOffset = Vector(0.0, 0.55, 0.55) * GetMinecraftBlockSize()
	MsgN("TraceStartOffset = ", TraceStartOffset)
end

function MinecraftInitMapChunkBounds()

	local MapBoundsMin, MapBoundsMax = game.GetWorld():GetModelBounds()
	local MapBoundsToChunksMul = GetMinecraftBlockSizeInv() / MapChunkSize

	MapChunkBoundsMin.X = math.max(math.floor(MapBoundsMin.X * MapBoundsToChunksMul), -8)
	MapChunkBoundsMin.Y = math.max(math.floor(MapBoundsMin.Y * MapBoundsToChunksMul), -8)
	MapChunkBoundsMin.Z = math.max(math.floor((MapBoundsMin.Z - GetGlobalOffsetZ()) * MapBoundsToChunksMul), -4)

	MapChunkBoundsMax.X = math.min(math.floor(MapBoundsMax.X * MapBoundsToChunksMul), 8)
	MapChunkBoundsMax.Y = math.min(math.floor(MapBoundsMax.Y * MapBoundsToChunksMul), 8)
	MapChunkBoundsMax.Z = math.min(math.floor((MapBoundsMax.Z - GetGlobalOffsetZ()) * MapBoundsToChunksMul), 8)

	MsgN(Format("MinecraftInitChunkBounds() Ready: MapChunksMin = [%s], MapChunksMax = [%s]", MapChunkBoundsMin, MapChunkBoundsMax))
end

local bMinecraftShouldScanMap = false

function MinecraftGetShouldScanMap()
	return bMinecraftShouldScanMap
end

function MinecraftSetShouldScanMap(InValue)
	bMinecraftShouldScanMap = InValue
end

local bMinecraftMapScanInProgress = false

function MinecraftIsMapScanInProgress()
	return bMinecraftMapScanInProgress
end

local MinecraftChunkToSend = {}
local MinecraftChunkToSend_InProgress = {}

function MinecraftHasChunkToSend()
	return not table.IsEmpty(MinecraftChunkToSend)
end

function MinecraftGetChunkToSend()
	return MinecraftChunkToSend
end

local MinecraftChunkSendCoroutine = nil

function MinecraftGetChunkSendCoroutine()
	return MinecraftChunkSendCoroutine
end

function MinecraftTestInitAndStartMapScan()

	MinecraftInitAndStartMapScan()
	timer.Create("TestMapScan", 1.0 / 20.0, 0, MinecraftTestStartScanNextChunk)
end

function MinecraftTestStartScanNextChunk()

	if MinecraftChunkSendCoroutine == nil then
		timer.Remove("TestMapScan")
	else
		MinecraftStartScanNextChunk()
	end
end

function MinecraftStartScanNextChunk()

	table.Empty(MinecraftChunkToSend)
	local bSuccess, Message = coroutine.resume(MinecraftChunkSendCoroutine)

	if not bSuccess then
		MsgN(Message)
	end
end

function MinecraftInitAndStartMapScan()

	MinecraftInitMapChunkBounds()

	MinecraftChunkSendCoroutine = coroutine.create(function()

		bMinecraftMapScanInProgress = true
		local ChunkID = 0

		for z = MapChunkBoundsMin.Z, MapChunkBoundsMax.Z do
			for x = MapChunkBoundsMin.X, MapChunkBoundsMax.X do
				for y = MapChunkBoundsMin.Y, MapChunkBoundsMax.Y do

					MinecraftMapScanChunk(ChunkID, x, y, z)
					--PrintTable(MinecraftChunkToSend_InProgress)
					if not table.IsEmpty(MinecraftChunkToSend_InProgress.points) then
						table.CopyFromTo(MinecraftChunkToSend_InProgress, MinecraftChunkToSend)
					end
					table.Empty(MinecraftChunkToSend_InProgress)
					--PrintTable(MinecraftChunkToSend)
					ChunkID = ChunkID + 1
	            	coroutine.yield()
				end
			end
			PrintMessage(HUD_PRINTTALK, Format("Map scan progress: %i%%", (z - MapChunkBoundsMin.Z + 1) / (MapChunkBoundsMax.Z - MapChunkBoundsMin.Z + 1) * 100))
		end

		MinecraftChunkSendCoroutine = nil
		MinecraftChunkToSend = {}

		bMinecraftMapScanInProgress = false
	end)
	--MsgN(MinecraftChunkSendCoroutine)
	MinecraftStartScanNextChunk()
end

function MinecraftMapScanChunk(InID, InOffsetX, InOffsetY, InOffsetZ)

	--MsgN(Format("MinecraftMapScanChunk() %s, [%s, %s, %s]", InID, InOffsetX, InOffsetY, InOffsetZ))
	MinecraftChunkToSend_InProgress = { ID = InID, points = {} }
	local OccludedCoords = {}
	local BoundsStart = Vector(-MapChunkSize + InOffsetX * MapChunkSize, -MapChunkSize + InOffsetY * MapChunkSize, -MapChunkSize + InOffsetZ * MapChunkSize)
	local BoundsEnd = Vector(MapChunkSize + InOffsetX * MapChunkSize, MapChunkSize + InOffsetY * MapChunkSize, MapChunkSize + InOffsetZ * MapChunkSize)
	--MsgN(BoundsStart, BoundsEnd)
	--[[if MinecraftMapScanChunkEarlyOutCheck(BoundsStart, BoundsEnd) then --Seems to not work because there's no overlap until we leave solid area
		return
	end--]]

	for x = BoundsStart.x, BoundsEnd.x do
		for y = BoundsStart.y, BoundsEnd.y do
			for z = BoundsStart.z, BoundsEnd.z do
				MinecraftMapTraceOnCoords(OccludedCoords, x, y, z)
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
						--debugoverlay.Box(BlockLocation, Vector(1,1,1) * -GetMinecraftBlockSize(), Vector(1,1,1) * GetMinecraftBlockSize(), 1.0)

						table.insert(MinecraftChunkToSend_InProgress.points, BlockLocation.X)
						table.insert(MinecraftChunkToSend_InProgress.points, BlockLocation.Z)
						table.insert(MinecraftChunkToSend_InProgress.points, -BlockLocation.Y)
						table.insert(MinecraftChunkToSend_InProgress.points, OccludedCoords[x][y][z])
						--MsgN(Format("Material: %i", OccludedCoords[x][y][z]))
					end
				end
			end
		end
	end
	--PrintTable(MinecraftChunkToSend_InProgress)
end

function MinecraftTestMapTraceFromView()

	local PlayerTrace = util.TraceLine(util.GetPlayerTrace(player.GetAll()[1]))
	local Coords = PlayerTrace.HitPos * GetMinecraftBlockSizeInv()
	MsgN(Format("Coords: %i, %i, %i", math.Round(Coords.X), math.Round(Coords.Y), math.Round(Coords.Z)))
	MinecraftMapTraceOnCoords({}, math.Round(Coords.X), math.Round(Coords.Y), math.Round(Coords.Z))
end

local EarlyOutTraceStartOffset = Vector(0.0, 0.0, 1.0)

function MinecraftMapScanChunkEarlyOutCheck(InBoundsStart, InBoundsEnd)
	--MsgN(MapChunkSizeUnitsMin, MapChunkSizeUnitsMax)
	local TraceStart = InBoundsStart + (InBoundsEnd - InBoundsStart) * 0.5

	local TraceResult = util.TraceLine({
		start = TraceStart - EarlyOutTraceStartOffset,
		endpos = TraceStart + EarlyOutTraceStartOffset,
		mins = MapChunkSizeUnitsMin,
		maxs = MapChunkSizeUnitsMax,
		mask = CONTENTS_SOLID})
	--PrintTable(TraceResult)
	--debugoverlay.Box(TraceStart, MapChunkSizeUnitsMin, MapChunkSizeUnitsMax, 5.0)
	if not TraceResult.HitWorld then
		MsgN("Discarded chunk")
		--debugoverlay.Box(TraceStart, MapChunkSizeUnitsMin, MapChunkSizeUnitsMax, 30.0)
		return true
	end
	return false
end

function MinecraftMapTraceOnCoords(InTable, x, y, z)

	local TraceEnd = Vector(x, y, z) * GetMinecraftBlockSize() + GetMinecraftBlockCenterOffset()

	local TraceResult = util.TraceLine({
		start = TraceEnd + TraceStartOffset,
		endpos = TraceEnd,
		mask = CONTENTS_SOLID})

	if TraceResult.HitTexture == "**empty**" then
		TraceResult = util.TraceLine({
		start = TraceEnd - TraceStartOffset,
		endpos = TraceEnd,
		mask = CONTENTS_SOLID})
	end
	--debugoverlay.Box(TraceEnd, Vector(0.5, 0.5, 0.5) * -GetMinecraftBlockSize(), Vector(0.5, 0.5, 0.5) * GetMinecraftBlockSize(), 1.0)

	--PrintTable(TraceResult)
	--MsgN("==============")

	if TraceResult.Fraction < 1 and TraceResult.HitWorld and TraceResult.MatType ~= MAT_DEFAULT then

		--debugoverlay.Box(TraceEnd, Vector(0.5, 0.5, 0.5) * -GetMinecraftBlockSize(), Vector(0.5, 0.5, 0.5) * GetMinecraftBlockSize(), 1.0)

		if InTable[x] == nil then
			InTable[x] = {}
		end

		if InTable[x][y] == nil then
			InTable[x][y] = {}
		end
		InTable[x][y][z] = GetMinecraftMaterialIndex(TraceResult.HitTexture)
		--MsgN(Format("Index: %s", InTable[x][y][z]))
		--MsgN(Format("HitTexture: %s", TraceResult.HitTexture))

		if InTable[x][y][z] > 0 then
			debugoverlay.Box(TraceEnd, Vector(0.5, 0.5, 0.5) * -GetMinecraftBlockSize(), Vector(0.5, 0.5, 0.5) * GetMinecraftBlockSize(), 15.0)
		end
	end
end
