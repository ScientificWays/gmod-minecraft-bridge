---- Minecraft Bridge
---- Server autorun logic

if game.SinglePlayer() or not string.StartWith(game.GetMap(), "mb_") then

	return
end

local bMinecraftBridgeEnabled = false

local UUIDEntityList = {}

local MinecraftSendEventList = {}

local MinecraftBridgeIP = "26.221.65.181"
local MinecraftBridgePort = "1820"
local MinecraftPostGmodDataURL = ""
local MinecraftPostGmodEntitiesURL = ""

function UpdateMinecraftPostURL()

	MinecraftPostGmodDataURL = "http://"..MinecraftBridgeIP..":"..MinecraftBridgePort.."/postGmodData"

	MinecraftPostGmodEntitiesURL = "http://"..MinecraftBridgeIP..":"..MinecraftBridgePort.."/postGmodEntities"
end

UpdateMinecraftPostURL()

local MinecraftPlayerHullMin, MinecraftPlayerHullMax = Vector(-12.0, -12.0, 0), Vector(12.0, 12.0, 60.0)
local MinecraftPlayerHullDuckMin, MinecraftPlayerHullDuckMax = Vector(-12.0, -12.0, 0.0), Vector(12.0, 12.0, 50.0)

local MinecraftPlayerViewOffset = Vector(0.0, 0.0, 64.0)
local MinecraftPlayerViewOffsetDuck = Vector(0.0, 0.0, 28.0)

local MinecraftPlayerModelScale = 1.0
local MinecraftPlayerJumpPower = 200

local MinecraftBlockSize = 64.0
local MinecraftBlockSizeInv = 1.0 / MinecraftBlockSize

local MinecraftBlockBias = Vector(MinecraftBlockSize, -MinecraftBlockSize, MinecraftBlockSize) * 0.5

local MinecraftBlockColorList = {
	["minecraft:stone"] = Color(128, 128, 128),
	["minecraft:grass_block"] = Color(0, 128, 0),
	["minecraft:dirt"] = Color(128, 60, 15),
	["minecraft:oak_planks"] = Color(255, 150, 120),
	["minecraft:oak_log"] = Color(200, 128, 75),
	["minecraft:white_wool"] = Color(255, 255, 255),
	["minecraft:orange_wool"] = Color(255, 128, 0),
	["minecraft:magenta_wool"] = Color(200, 60, 128),
	["minecraft:light_blue_wool"] = Color(0, 255, 255),
	["minecraft:yellow_wool"] = Color(255, 255, 0),
	["minecraft:lime_wool"] = Color(0, 255, 0),
	["minecraft:pink_wool"] = Color(255, 128, 128),
	["minecraft:gray_wool"] = Color(190, 190, 190),
	["minecraft:light_gray_wool"] = Color(225, 225, 225),
	["minecraft:cyan_wool"] = Color(0, 200, 200),
	["minecraft:purple_wool"] = Color(255, 70, 255),
	["minecraft:blue_wool"] = Color(0, 0, 255),
	["minecraft:brown_wool"] = Color(128, 60, 60),
	["minecraft:green_wool"] = Color(0, 255, 0),
	["minecraft:red_wool"] = Color(255, 0, 0),
	["minecraft:black_wool"] = Color(0, 0, 0)
}

local MinecraftHandToWeaponTable = {
	["minecraft:iron_sword"] = "weapon_crowbar",
	["minecraft:crossbow"] = "weapon_crossbow",
	["minecraft:stick"] = "weapon_physgun",
	["minecraft:bow"] = "weapon_pistol",
	["minecraft:spyglass"] = "gmod_camera"
}

local MinecraftDefaultWeaponTable = {
	"weapon_physgun",
	"weapon_physcannon",
	"weapon_crowbar",
	"weapon_pistol",
	"weapon_357",
	"weapon_smg1",
	"weapon_ar2",
	"weapon_shotgun",
	"weapon_crossbow",
	"weapon_rpg",
	"weapon_frag",
	"gmod_tool",
	"gmod_camera"
}

local VehicleDataList = {
	["prop_vehicle_jeep"] = {Class = "Jeep", LocalBias = Vector(-32.0, -8.0, 0.0)},
	["prop_vehicle_jeep_old"] = {Class = "Jeep", LocalBias = Vector(-32.0, -8.0, 0.0)},
	["prop_vehicle_airboat"] = {Class = "Airboat", LocalBias = Vector(0.0, -8.0, 0.0)},
	["prop_vehicle_prisoner_pod"] = {Class = "Chair", LocalBias = Vector(0.0, 0.0, 0.0)}
}

local ProjectileClassList = {
	["npc_satchel"] = "Slam",
	["npc_grenade_frag"] = "Grenade",
	["grenade_ar2"] = "Grenade",
	["rpg_missile"] = "Missile",
	["crossbow_bolt"] = "Bolt",
	["prop_combine_ball"] = "Ball",
	["npc_grenade_bugbait"] = "Bait",
	["hunter_flechette"] = "Flechette"
}

local MinecraftExplosiveClassList = {
	["npc_satchel"] = "Slam",
	["npc_grenade_frag"] = "Grenade",
	["grenade_ar2"] = "Grenade",
	["rpg_missile"] = "Missile",
	["prop_combine_ball"] = "Ball"
}

local MinecraftExplosiveModelList = {
	["models/props_c17/oildrum001_explosive.mdl"] = true,
	["models/props_phx/misc/potato_launcher_explosive.mdl"] = true,
	["models/props_phx/oildrum001_explosive.mdl"] = true
}

local InputFilter = {
	"Use"
}

local StaticEntityFilter = {
	"func_button"
}

function SetMinecraftBridgeIP(InIP)

	MsgN("SetMinecraftBridgeIP()")

	MinecraftBridgeIP = InIP

	UpdateMinecraftPostURL()
end

function SetMinecraftBridgePort(InPort)

	MsgN("SetMinecraftBridgePort()")

	MinecraftBridgePort = InPort

	UpdateMinecraftPostURL()
end

function ToggleMinecraftBridge(InTickRate)

	MsgN("ToggleMinecraftBridge()")

	--table.Empty(UUIDEntityList)

	table.Empty(MinecraftSendEventList)

	if bMinecraftBridgeEnabled then

		bMinecraftBridgeEnabled = false

		timer.Remove("MinecraftBridgePost")

		for SampleUUID, SampleEntity in pairs(UUIDEntityList) do

			if SampleEntity.bMinecraftEntity then

				RemoveMinecraftEntity(SampleUUID)
			end
		end

		for SampleIndex, SamplePlayer in ipairs(player.GetAll()) do

			SamplePlayer:Spawn()
		end

		hook.Remove("SetupMove", "MinecraftUpdateMove")

		hook.Remove("StartCommand", "MinecraftCommand")

		PrintMessage(HUD_PRINTTALK, "Minecraft bridge disabled!")
	else

		--MsgN(InTickRate)

		bMinecraftBridgeEnabled = true

		MinecraftInitStaticEntities()

		hook.Add("SetupMove", "MinecraftUpdateMove", MinecraftUpdateMove_Implementation)

		hook.Add("StartCommand", "MinecraftCommand", MinecraftCommand_Implementation)

		timer.Create("MinecraftBridgePost", 1.0 / (InTickRate or 10.0), 0, MinecraftBridgePostTick)

		for SampleIndex, SamplePlayer in ipairs(player.GetAll()) do

			InitializeBridgePlayer(SamplePlayer)

			SamplePlayer:Spawn()
		end

		PrintMessage(HUD_PRINTTALK, "Minecraft bridge enabled!")
	end
end

hook.Add("PlayerInitialSpawn", "MinecraftPlayerInitialSpawn", function(InPlayer, bTransition)

	InitializeBridgePlayer(InPlayer)
end)

function InitializeBridgePlayer(InPlayer)

	if not bMinecraftBridgeEnabled then

		return
	end

	if not InPlayer:IsBot() then

		InPlayer.uuid = InPlayer:SteamID()

		InPlayer.Target = ""

		UUIDEntityList[InPlayer.uuid] = InPlayer
	end
end

hook.Add("PlayerSpawn", "MinecraftPlayerSpawn", function(InPlayer, bTransition)

	--MsgN("PlayerSpawn()")

	--[[if not bMinecraftBridgeEnabled then

		return
	end--]]

	if InPlayer:IsNextBot() then

		timer.Simple(0.0, function()

			if bMinecraftBridgeEnabled then

				InPlayer:SetHull(MinecraftPlayerHullMin, MinecraftPlayerHullMax)

				InPlayer:SetHullDuck(MinecraftPlayerHullDuckMin, MinecraftPlayerHullDuckMax)

				InPlayer:SetViewOffset(MinecraftPlayerViewOffset)

				InPlayer:SetViewOffsetDucked(MinecraftPlayerViewOffsetDuck)

				InPlayer:SetModelScale(MinecraftPlayerModelScale)

				InPlayer:SetJumpPower(MinecraftPlayerJumpPower)
			else
				InPlayer:ResetHull()

				InPlayer:SetModelScale(1.0)
			end
		end)
	end
end)

hook.Add("PlayerLoadout", "MinecraftPlayerLoadout", function(InPlayer)

	--MsgN("PlayerLoadout()")

	if not bMinecraftBridgeEnabled then

		return
	end

	if not InPlayer:IsNextBot() then

		InPlayer:StripWeapons()

		InPlayer:StripAmmo()

		for SampleIndex, SampleWeaponClass in ipairs(MinecraftDefaultWeaponTable) do

			local SampleWeapon = InPlayer:Give(SampleWeaponClass)

			MsgN(SampleWeapon:GetPrimaryAmmoType())

			InPlayer:SetAmmo(9999, SampleWeapon:GetPrimaryAmmoType())
		end

		return true
	end
end)

hook.Add("AllowPlayerPickup", "MinecraftAllowPlayerPickup", function(InPlayer, InEntity)

	--MsgN("AllowPlayerPickup()")

	if string.StartWith(InEntity:GetClass(), "item_") and InEntity:CreatedByMap() then

		return false
	end
end)

function CreateMinecraftEntity(InEntityData)

	--MsgN("CreateMinecraftEntity()")

	local UniqueID = InEntityData.uuid or "invalid"

	local EntityName = InEntityData.name or "no name for entity"

	if InEntityData.type == "Player" then

		UUIDEntityList[UniqueID] = player.CreateNextBot(EntityName)

		UUIDEntityList[UniqueID]:Spawn()

		UUIDEntityList[UniqueID]:SetPos(Vector(InEntityData.x, -InEntityData.z, InEntityData.y))

		--UUIDEntityList[UniqueID]:SetAngles(Angle(InEntityData.pitch, -InEntityData.yaw - 90.0, 0.0))

		UUIDEntityList[UniqueID]:SetEyeAngles(Angle(InEntityData.pitch, -InEntityData.yaw - 90.0, 0.0))

		UUIDEntityList[UniqueID]:SetActivity(ACT_RUN)

		UUIDEntityList[UniqueID]:EmitSound("Player.DrownContinue")
	end

	UUIDEntityList[UniqueID].uuid = UniqueID

	UUIDEntityList[UniqueID].bMinecraftEntity = true
end

function CreateMinecraftProjectile(InEntityData)

	--MsgN("CreateMinecraftProjectile()")

	--local ProjectileEffectData = EffectData()

	--ProjectileEffectData:SetOrigin(Vector(InEntityData.x, -InEntityData.z, InEntityData.y))

	--ProjectileEffectData:SetAngles(Angle(InEntityData.pitch, -InEntityData.yaw - 90.0, 0.0))

	--ProjectileEffectData:SetScale(10.0)

	--ProjectileEffectData:SetFlags(1)

	--ProjectileEffectData:SetStart(Vector(InEntityData.x + 16.0, -InEntityData.z, InEntityData.y))

	--local ProjectileEffectName = ""

	local EffectOrigin = Vector(InEntityData.x, -InEntityData.z, InEntityData.y)

	if InEntityData.class == "Arrow" then

		--ProjectileEffectName = "GunshipTracer"

		local EffectEndPos = Vector(MinecraftBlockSize, 0.0, 0.0)

		EffectEndPos:Rotate(Angle(InEntityData.pitch, -InEntityData.yaw - 90.0, 0.0))

		effects.BubbleTrail(EffectOrigin, EffectOrigin + EffectEndPos, 16, EffectOrigin.z + MinecraftBlockSize * 0.25, 0.1, 0.1)

		--util.Effect("Tracer", ProjectileEffectData)

	elseif InEntityData.class == "Potion" then

		--ProjectileEffectName = "VortDispel"

		effects.BubbleTrail(EffectOrigin, EffectOrigin, 4, EffectOrigin.z + MinecraftBlockSize * 2.0, 0.1, 0.1)

	elseif InEntityData.class == "Trident" then

		local EffectEndPos = Vector(MinecraftBlockSize, 0.0, 0.0)

		EffectEndPos:Rotate(Angle(InEntityData.pitch, -InEntityData.yaw - 90.0, 0.0))

		effects.BubbleTrail(EffectOrigin, EffectOrigin + EffectEndPos, 32, EffectOrigin.z + MinecraftBlockSize, 0.1, 0.1)
	end
end

function UpdateMinecraftEntity(InEntityData)

	local MinecraftEntity = UUIDEntityList[InEntityData.uuid]

	if MinecraftEntity:IsPlayer() then

		if InEntityData.health > 0 and not MinecraftEntity:Alive() then

			MinecraftEntity:Spawn()

		elseif InEntityData.health <= 0 and MinecraftEntity:Alive() then

			MinecraftEntity:Kill()
		end

		local WeaponClass = MinecraftHandToWeaponTable[InEntityData.hand]

		if MinecraftBlockColorList[InEntityData.hand] ~= nil then

			WeaponClass = "weapon_crowbar"
		end

		if WeaponClass ~= nil then

			MinecraftEntity:Give(WeaponClass)

			MinecraftEntity:SetActiveWeapon(MinecraftEntity:GetWeapon(WeaponClass))
		else
			MinecraftEntity:StripWeapons()
		end

		--local bFlaslightOn = InEntityData.bFlashlight == "true"

		--MsgN(bFlaslightOn)

		if InEntityData.bFlashlight ~= MinecraftEntity:FlashlightIsOn() then

			MsgN(InEntityData.bFlashlight)

			MinecraftEntity:Flashlight(InEntityData.bFlashlight)
		end
	end

	MinecraftEntity:SetHealth(InEntityData.health * 5.0)

	MinecraftEntity.LerpPos = Vector(InEntityData.x, -InEntityData.z, InEntityData.y)

	MinecraftEntity.LerpAngles = Angle(InEntityData.pitch, -InEntityData.yaw - 90.0, 0.0)

	--MsgN(InEntityData.isSitting, InEntityData.isSitting == "1")

	MinecraftEntity.bCrouching = InEntityData.isSitting == "1"

	--MsgN(MinecraftEntity.bCrouching)
end

function RemoveMinecraftEntity(InUUID)

	--MsgN("RemoveMinecraftEntity()")

	local MinecraftEntity = UUIDEntityList[InUUID]

	if MinecraftEntity:IsPlayer() then

		MinecraftEntity:EmitSound("Player.FallGib")

		MinecraftEntity:Kick("Minecraft Disconnect")
	else
		MinecraftEntity:EmitSound("Bounce.Metal")

		MinecraftEntity:Remove()
	end

	UUIDEntityList[InUUID] = nil
end

function MinecraftBridgePostTick()

	--MsgN("MinecraftBridgePostTick")

	local OutTable = {entities = {}, events = {}}

	for SampleIndex, SamplePlayer in ipairs(player.GetHumans()) do

		local SamplePos = SamplePlayer:GetPos()

		local SampleAngles = SamplePlayer:EyeAngles()

		local SampleWeapon = SamplePlayer:GetActiveWeapon()

		local SampleWeaponClass = "none"

		local SampleHandColor = SamplePlayer:GetWeaponColor()

		if IsValid(SampleWeapon) then

			SampleWeaponClass = SampleWeapon:GetClass()
		end

		table.insert(OutTable.entities, {
			["type"] = "player",
			["name"] = SamplePlayer:Nick(),
			["health"] = SamplePlayer:Health(),
			["x"] = math.Round(SamplePos.x),
			["y"] = math.Round(SamplePos.z),
			["z"] = -math.Round(SamplePos.y),
			["pitch"] = math.Round(SampleAngles.pitch),
			["yaw"] = -math.Round(SampleAngles.yaw),
			["uuid"] = SamplePlayer.uuid,
			["isAlive"] = tostring(SamplePlayer:Alive()),
			["isSitting"] = tostring(SamplePlayer:Crouching() or ""),
			["hand"] = SampleWeaponClass,
			["hand_color_r"] = math.Round(SampleHandColor.x, 2),
			["hand_color_g"] = math.Round(SampleHandColor.y, 2),
			["hand_color_b"] = math.Round(SampleHandColor.z, 2),
			["isUsing"] = SamplePlayer:KeyDown(IN_ATTACK),
			["target"] = SamplePlayer.Target
		})
	end

	for SampleIndex, SampleNPC in ipairs(ents.FindByClass("npc*")) do

		local SampleClass = SampleNPC:GetClass()

		if SampleClass ~= "npc_grenade_frag" and SampleClass ~= "npc_grenade_bugbait" and SampleClass ~= "npc_satchel" then

			local SamplePos = SampleNPC:GetPos()

			local SampleAngles = SampleNPC:EyeAngles()

			local SampleWeapon = SampleNPC:GetActiveWeapon()

			local SampleWeaponClass = "none"

			if IsValid(SampleWeapon) then

				SampleWeaponClass = SampleWeapon:GetClass()
			end

			table.insert(OutTable.entities, {
				["type"] = "npc",
				["class"] = SampleNPC:GetClass(),
				["health"] = SampleNPC:Health(),
				["x"] = math.Round(SamplePos.x),
				["y"] = math.Round(SamplePos.z),
				["z"] = -math.Round(SamplePos.y),
				["pitch"] = math.Round(SampleAngles.pitch),
				["yaw"] = -math.Round(SampleAngles.yaw),
				["uuid"] = SampleNPC.uuid,
				["hand"] = SampleWeaponClass
			})
		end
	end

	for SampleIndex, SampleVehicle in ipairs(ents.FindByClass("prop_vehicle*")) do

		local SamplePos = SampleVehicle:GetPos()

		local SampleAngles = SampleVehicle:EyeAngles()

		--MsgN(SampleVehicle)

		local SampleVehicleClass = "Default"

		local SampleLocalBias = Vector(0.0, 0.0, 0.0)

		if VehicleDataList[SampleVehicle:GetClass()] ~= nil then

			SampleVehicleClass = VehicleDataList[SampleVehicle:GetClass()].Class

			SampleLocalBias:Set(VehicleDataList[SampleVehicle:GetClass()].LocalBias)

			SampleLocalBias:Rotate(Angle(SampleAngles.pitch, -SampleAngles.yaw, SampleAngles.roll))
		end

		--MsgN(SampleVehicle:GetDriver())

		--MsgN(SampleVehicle:GetDriver().uuid)

		table.insert(OutTable.entities, {
			["type"] = "vehicle",
			["class"] = SampleVehicleClass,
			["x"] = tostring(math.Round(SamplePos.x + SampleLocalBias.x)),
			["y"] = tostring(math.Round(SamplePos.z + SampleLocalBias.z)),
			["z"] = tostring(-math.Round(SamplePos.y + SampleLocalBias.y)),
			["pitch"] = tostring(math.Round(SampleAngles.pitch)),
			["yaw"] = tostring(-math.Round(SampleAngles.yaw - 90.0)),
			["uuid"] = SampleVehicle.uuid,
			["driver"] = SampleVehicle:GetDriver().uuid or "none",
			["steering"] = SampleVehicle:GetSteering()
		})
	end

	for SampleIndex, SampleProp in ipairs(ents.FindByClass("prop_physics*")) do

		local SamplePos = SampleProp:GetPos()

		local SampleAngles = SampleProp:EyeAngles()

		local BoundsMin, BoundsMax = SampleProp:GetModelBounds()

		table.insert(OutTable.entities, {
			["type"] = "prop",
			["name"] = SampleProp:GetName(),
			["x"] = tostring(math.Round(SamplePos.x)),
			["y"] = tostring(math.Round(SamplePos.z)),
			["z"] = tostring(-math.Round(SamplePos.y)),
			["pitch"] = tostring(math.Round(SampleAngles.pitch)),
			["yaw"] = tostring(-math.Round(SampleAngles.yaw)),
			["height"] = tostring(math.Round(BoundsMax.z - BoundsMin.z)),
			["uuid"] = SampleProp.uuid
		})
	end

	for SampleEntityClass, SampleProjectileClass in pairs(ProjectileClassList) do

		--MsgN(SampleEntityClass)

		for SampleIndex, SampleProjectile in ipairs(ents.FindByClass(SampleEntityClass)) do

			--MsgN(SampleProjectile)

			local SamplePos = SampleProjectile:GetPos()

			local SampleAngles = SampleProjectile:EyeAngles()

			table.insert(OutTable.entities, {
				["type"] = "projectile",
				["class"] = SampleProjectileClass,
				["x"] = tostring(math.Round(SamplePos.x)),
				["y"] = tostring(math.Round(SamplePos.z)),
				["z"] = tostring(-math.Round(SamplePos.y)),
				["pitch"] = tostring(math.Round(SampleAngles.pitch)),
				["yaw"] = tostring(-math.Round(SampleAngles.yaw - 90.0)),
				["uuid"] = SampleProjectile.uuid
			})
		end
	end

	OutTable.events = table.Copy(MinecraftSendEventList)

	--PrintTable(OutTable.events)

	table.Empty(MinecraftSendEventList)

	--PrintTable(OutTable)

	local OutJSON = util.TableToJSON(OutTable)

	--local MessageLength = OutJSON:len()

	--MsgN(Format("MessageLength: %s", MessageLength))

	local OutRequest = {
		url			= MinecraftPostGmodDataURL,
		method		= "post",
		body		= OutJSON,
		type		= "application/json",

		--Parameters
		--OutTable,

		--Success Callback
		success = OnMinecraftPostSuccess,

		--Failure Callback
		failed = OnMinecraftPostFailure--,

		--Header
		--[[{
			["Content-Type"] = "application/json",
			["Content-Length"] = tostring(MessageLength)
		}--]]
	}
	HTTP(OutRequest)
end

function OnMinecraftPostSuccess(InCode, InBody, InHeaders)

	--MsgN(Format("OnMinecraftPostSuccess() body: %s", InBody))

	local SampleTable = util.JSONToTable(InBody) or {}

	local ValidUUIDTable = {}

	for SampleIndex, SampleEntityData in ipairs(SampleTable.entities or {}) do

		local UniqueID = SampleEntityData.uuid

		if SampleEntityData.type == "Projectile" then

			CreateMinecraftProjectile(SampleEntityData)

		else
			if not UUIDEntityList[UniqueID] then

				CreateMinecraftEntity(SampleEntityData)
			end

			UpdateMinecraftEntity(SampleEntityData)

			ValidUUIDTable[UniqueID] = true
		end
	end

	--PrintTable(UUIDEntityList)

	--PrintTable(ValidUUIDTable)

	for SampleUUID, SampleEntity in pairs(UUIDEntityList) do

		if SampleEntity.bMinecraftEntity then

			--MsgN(ValidUUIDTable[SampleUUID])

			if ValidUUIDTable[SampleUUID] == nil then

				RemoveMinecraftEntity(SampleUUID)
			end
		end
	end

	--PrintTable(SampleTable.events)

	for SampleIndex, SampleEventData in ipairs(SampleTable.events or {}) do

		if SampleEventData.type == "PlayerInteractButton" then

			local TargetEntity = Entity(SampleEventData.index)

			local ActivatorEntity = Entity(SampleEventData.activator or -1)

			TargetEntity:Input("Use", ActivatorEntity, TargetEntity, "_bridge")

		elseif SampleEventData.type == "Damage" then

			local TargetEntity = UUIDEntityList[SampleEventData.targetUuid]

			PrintTable(SampleEventData)

			--local AttackerEntity = UUIDEntityList[SampleEventData.AttackerUUID]

			local DamageValue = tonumber(SampleEventData.value) * 5.0

			--MsgN(TargetEntity)

			if TargetEntity ~= nil and DamageValue ~= nil then

				if TargetEntity:IsPlayer() and TargetEntity:InVehicle() then

					TargetEntity = TargetEntity:GetVehicle()
				end

				timer.Simple(0.0, function()

					local TargetDamageInfo = DamageInfo()

					TargetDamageInfo:SetInflictor(TargetEntity)

					TargetDamageInfo:SetAttacker(TargetEntity)

					TargetDamageInfo:SetDamage(DamageValue)

					TargetDamageInfo:SetDamageType(228)

					TargetEntity:TakeDamageInfo(TargetDamageInfo)
				end)
			end

		elseif SampleEventData.type == "ChatMessage" then

			local TargetPlayer = UUIDEntityList[SampleEventData.targetUuid]

			if TargetPlayer ~= nil and IsValid(TargetPlayer) then

				TargetPlayer:Say(SampleEventData.value)
			end

		elseif SampleEventData.type == "BlockPlace" then

			MinecraftBlockPlace(Vector(SampleEventData.x, -SampleEventData.z, SampleEventData.y) + MinecraftBlockBias, SampleEventData.id, SampleEventData.targetUuid)

		elseif SampleEventData.type == "BlockBreak" then

			MinecraftBlockBreak(Vector(SampleEventData.x, -SampleEventData.z, SampleEventData.y) + MinecraftBlockBias, SampleEventData.targetUuid)
		end
	end
end

function OnMinecraftPostFailure(InError)

	--MsgN(Format("OnMinecraftPostFailure() error: %s", InError))

	if bMinecraftBridgeEnabled then

		ToggleMinecraftBridge()
	end
end

function MinecraftBlockPlace(InBlockOrigin, InBlockID, InTargetUUID)

	MinecraftBlockBreak(InBlockOrigin, InTargetUUID)

	local BlockEntity = ents.Create("prop_dynamic")

	BlockEntity:SetModel("models/props_junk/wood_crate001a.mdl")

	BlockEntity:PhysicsInitBox(-MinecraftBlockBias, MinecraftBlockBias)

	--BlockEntity:SetModelScale(0.5)

	BlockEntity:SetModelScale(1.61 / 64.0 * MinecraftBlockSize, 0.5)

	BlockEntity:SetPos(InBlockOrigin)

	BlockEntity:PrecacheGibs()

	if MinecraftBlockColorList[InBlockID] then

		BlockEntity:SetColor(MinecraftBlockColorList[InBlockID])
	end

	BlockEntity:Spawn()

	BlockEntity.bMinecraftBlock = true

	local SamplePlayer = UUIDEntityList[InTargetUUID]

	if SamplePlayer ~= nil then

		SamplePlayer:DoAttackEvent()
	end
end

function MinecraftBlockBreak(InBlockOrigin, InTargetUUID)

	for SampleIndex, SampleEntity in ipairs(ents.FindInSphere(InBlockOrigin, MinecraftBlockSize * 0.25)) do

		--MsgN(SampleEntity)

		if SampleEntity.bMinecraftBlock then
		
			local SampleBreakForce = Vector(0.0, 0.0, 0.0)

			local SamplePlayer = UUIDEntityList[InTargetUUID]

			if SamplePlayer ~= nil then

				SamplePlayer:DoAttackEvent()

				SampleBreakForce = SampleEntity:GetPos() - SamplePlayer:GetPos()
			end

			SampleEntity:GibBreakClient(SampleBreakForce)

			SampleEntity.bMinecraftBlock = false

			SampleEntity:Remove()
		end
	end
end

function MinecraftUpdateMove_Implementation(InPlayer, InMoveData, InCommandData)

	if InPlayer:IsBot() then

		if InPlayer.LerpPos ~= nil then

			--MsgN(Format("PlayerPos: %s, LerpPos: %s", InPlayer:GetPos(), InPlayer.LerpPos))

			--InPlayer:SetPos(LerpVector(FrameTime(), InPlayer:GetPos(), InPlayer.LerpPos))

			local MoveVelocity = InPlayer.LerpPos - InMoveData:GetOrigin()

			InMoveData:SetVelocity(MoveVelocity * 10.0)

			--InMoveData:SetMaxClientSpeed(MoveVelocity:LengthSqr())

			InMoveData:SetOrigin(LerpVector(FrameTime() * 4.0, InMoveData:GetOrigin(), InPlayer.LerpPos))

			InPlayer:SetEyeAngles(LerpAngle(FrameTime() * 4.0, InMoveData:GetAngles(), InPlayer.LerpAngles))
		end
	end
end

function MinecraftCommand_Implementation(InPlayer, InCommandData)

	--MsgN(Format("%s: %s, %s", InPlayer, InPlayer:IsNextBot(), InPlayer:Alive()))

	if InPlayer:IsBot() and InPlayer:Alive() then

		InCommandData:ClearMovement()

		InCommandData:ClearButtons()

		--MsgN(Format("Crouching: %s", InPlayer.bCrouching))

		if InPlayer.bCrouching then

			InCommandData:SetButtons(IN_DUCK)
		end

		if InPlayer.bUsePrimary then

			InCommandData:SetButtons(IN_ATTACK)
		end
	end
end

hook.Add("OnEntityCreated", "MinecraftEntityCreated", function(InEntity)

	if IsValid(InEntity) then

		if not InEntity:IsPlayer() then

			InEntity.uuid = tostring(InEntity:EntIndex())

			if InEntity:GetName() == "" then

				InEntity:SetName(InEntity.uuid)
			end
		end

		if InEntity:IsNPC() then

			UUIDEntityList[InEntity.uuid] = InEntity
		end
	end
end)

hook.Add("EntityRemoved", "MinecraftEntityRemoved", function(InEntity)

	if not bMinecraftBridgeEnabled then

		return
	end

	--MsgN("EntityRemoved()")

	if IsValid(InEntity) then

		if InEntity.bMinecraftBlock then

			local BlockCoordinates = (InEntity:GetPos() - MinecraftBlockBias)

			table.insert(MinecraftSendEventList, {
				type = "gmodBlockBreak",
				x = math.Round(BlockCoordinates.x),
				y = math.Round(BlockCoordinates.z),
				z = -math.Round(BlockCoordinates.y)
			})
			return
		end

		if MinecraftExplosiveClassList[InEntity:GetClass()] then
			
			HandleMinecraftEntityExplosionEvent(InEntity)

			return
		end
	end
end)

hook.Add("PropBreak", "MinecraftPropBreak", function(InAttacker, InProp)

	if not bMinecraftBridgeEnabled then

		return
	end

	--MsgN("PropBreak()")

	if IsValid(InProp) then

		if MinecraftExplosiveModelList[InProp:GetModel()] then

			HandleMinecraftEntityExplosionEvent(InProp)
		end
	end
end)

function HandleMinecraftEntityExplosionEvent(InEntity)

	local SamplePos = InEntity:GetPos()

	table.insert(MinecraftSendEventList, {
		type = "Explosion",
		x = math.Round(SamplePos.x),
		y = math.Round(SamplePos.z),
		z = -math.Round(SamplePos.y)
	})
end

hook.Add("AcceptInput", "MinecraftMapInput", function(InEntity, InInput, InActivator, InCaller, InValue)

	if not bMinecraftBridgeEnabled then

		return
	end
	
	--MsgN(InInput)

	if table.HasValue(InputFilter, InInput) and InValue ~= "_bridge" then

		local EntityClass = InEntity:GetClass()

		if EntityClass == "func_button" then

			InEntity.LastTimeActivate = InEntity.LastTimeActivate or 0.0

			if InEntity.LastTimeActivate + 3.0 > CurTime() then

				return true
			else
				InEntity.LastTimeActivate = CurTime()
			end
		end

		table.insert(MinecraftSendEventList, {
			type = InInput,
			index = InEntity:EntIndex(),
			activator = InActivator.uuid or "",
			value = tostring(InValue or "")
		})
	end
end)

hook.Add("InitPostEntity", "MinecraftInitStaticEntities", function()

	
end)

function MinecraftInitStaticEntities()

	local OutTable = {}

	for SampleIndex, SampleEntity in ipairs(ents.GetAll()) do

		if IsValid(SampleEntity) then

			local EntityClass = SampleEntity:GetClass()

			if table.HasValue(StaticEntityFilter, EntityClass) then

				local EntityIndex = SampleEntity:EntIndex()

				local EntityPos = SampleEntity:GetPos()

				table.insert(OutTable, {class = EntityClass, index = EntityIndex, x = EntityPos.x, y = EntityPos.z, z = -EntityPos.y})
			end
		end
	end

	local OutJSON = util.TableToJSON(OutTable)

	print(OutJSON)

	local OutRequest = {
		url			= MinecraftPostGmodEntitiesURL,
		method		= "post",
		body		= OutJSON,
		type		= "application/json",

		--Parameters
		--OutTable,

		--Success Callback
		success = OnMinecraftInitStaticEntitiesSuccess,

		--Failure Callback
		failed = OnMinecraftInitStaticEntitiesFailure--,

		--Header
		--[[{
			["Content-Type"] = "application/json",
			["Content-Length"] = tostring(MessageLength)
		}--]]
	}
	HTTP(OutRequest)
end

local function OnMinecraftInitStaticEntitiesSuccess(InCode, InBody, InHeaders)

	MsgN(Format("OnMinecraftInitStaticEntitiesSuccess() body: %s", InBody))


end

local function OnMinecraftInitStaticEntitiesFailure(InError)

	MsgN(Format("OnMinecraftInitStaticEntitiesFailure() error: %s", InError))


end

hook.Add("PhysgunPickup", "MinecraftPhysgunTargetPickup", function(InPlayer, InEntity)

	--MsgN("PhysgunPickup")

	return InEntity:GetClass() ~= "player" and not InEntity.bMinecraftBlock
end)

hook.Add("OnPhysgunPickup", "MinecraftPhysgunTargetPickup", function(InPlayer, InEntity)

	if not bMinecraftBridgeEnabled then

		return
	end

	--MsgN("OnPhysgunPickup")

	if InEntity.uuid then

		InPlayer.Target = InEntity.uuid
	end
end)

hook.Add("PhysgunDrop", "MinecraftPhysgunTargetRelease", function(InPlayer, InEntity)

	if not bMinecraftBridgeEnabled then

		return
	end

	--MsgN("PhysgunDrop")

	InPlayer.Target = ""
end)

hook.Add("OnPhysgunFreeze", "MinecraftPhysgunFreeze", function(InWeapon, InPhysObj, InEntity, InPlayer)

	if not bMinecraftBridgeEnabled then

		return
	end
	
	--MsgN("OnPhysgunFreeze")

	local WeaponColor = InPlayer:GetWeaponColor()

	table.insert(MinecraftSendEventList, {
		type = "Freeze",
		targetUuid = InEntity.uuid,
		hand_color_r = math.Round(WeaponColor.x, 2),
		hand_color_g = math.Round(WeaponColor.y, 2),
		hand_color_b = math.Round(WeaponColor.z, 2)
	})
end)

hook.Add("EntityTakeDamage", "MinecraftTakeDamage", function(InEntity, InDamageInfo)

	--MsgN("EntityTakeDamage")

	if not bMinecraftBridgeEnabled then

		return
	end
	
	if InDamageInfo:GetDamageType() == 228 then

		return
	end

	if InEntity.bMinecraftBlock then

		return
	end

	if InEntity:IsPlayer() or InEntity:IsNPC() then

		table.insert(MinecraftSendEventList, {
			type = "Damage",
			targetUuid = InEntity.uuid,
			attackerUuid = InDamageInfo:GetAttacker().uuid or "",
			dmgtype = InDamageInfo:GetDamageType(),
			value = math.Round(InDamageInfo:GetDamage())
		})
		--PrintTable(MinecraftSendEventList)

		return InEntity.bMinecraftEntity
	end
end)

hook.Add("PlayerSay", "MinecraftChatEvent", function(InPlayer, InText, bTeamChat)

	--MsgN("PlayerSay")

	if string.StartWith(InText, "/") and InPlayer:IsAdmin() then

		local CommandData = string.Split(InText, " ")

		--PrintTable(CommandData)

		if CommandData[1] == "/mbip" then

			SetMinecraftBridgeIP(CommandData[2])

			return ""

		elseif CommandData[1] == "/mbport" then

			SetMinecraftBridgePort(CommandData[2])

			return ""

		elseif CommandData[1] == "/mbtoggle" then

			ToggleMinecraftBridge(tonumber(CommandData[2]))

			return ""
		end

		return
	end

	if not bMinecraftBridgeEnabled then

		return
	end
	
	if InPlayer.bMinecraftEntity then

		return
	end

	table.insert(MinecraftSendEventList, {
		type = "ChatMessage",
		targetUuid = InPlayer.uuid,
		value = InText,
		team = tostring(bTeamChat)
	})
end)

hook.Add("PlayerSwitchFlashlight", "MinecraftSwitchFlashlight", function(InPlayer, bEnabled)

	--MsgN("PlayerSwitchFlashlight")

	if not bMinecraftBridgeEnabled then

		return
	end
	
	if InPlayer.bMinecraftEntity then

		return
	end

	table.insert(MinecraftSendEventList, {
		type = "Flashlight",
		targetUuid = InPlayer.uuid,
		value = tostring(bEnabled)
	})
end)
