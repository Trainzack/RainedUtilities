
-- helper function to open file, and error on failure
-- (Shamelessly stolen from rendercopy)
local function openFile(p, mode)
    local f = io.open(p, mode)
    if not f then
        error("could not open " .. p, 2)
    end
    return f
end

local path = require("path")
local imgui = require("imgui")

local function getOutputCoord(level, pos)
	return {
		x = (pos.x - level.borderLeft),
		y = (pos.y - level.borderTop)
	}
end


local OUTPUT_GEO = {
	AIR = 0,
	SOLID = 1,
	SLOPE = 2,
	FLOOR = 3,
	SHORTCUT_ENTRANCE = 4
}


local GEO_TO_OUTPUT_MAPPING = {
	[GEO_TYPE.AIR] 					= OUTPUT_GEO.AIR,
	[GEO_TYPE.SOLID] 				= OUTPUT_GEO.SOLID,
	[GEO_TYPE.SLOPE_RIGHT_UP] 		= OUTPUT_GEO.SLOPE,
	[GEO_TYPE.SLOPE_LEFT_UP] 		= OUTPUT_GEO.SLOPE,
	[GEO_TYPE.SLOPE_RIGHT_DOWN] 	= OUTPUT_GEO.SLOPE,
	[GEO_TYPE.SLOPE_LEFT_DOWN] 		= OUTPUT_GEO.SLOPE,
	[GEO_TYPE.FLOOR] 				= OUTPUT_GEO.FLOOR,
	[GEO_TYPE.SHORTCUT_ENTRANCE] 	= OUTPUT_GEO.SHORTCUT_ENTRANCE,
	[GEO_TYPE.GLASS] 				= OUTPUT_GEO.SOLID
}

local GEO_BOX_DRAWINGS = {
	[GEO_TYPE.AIR] 					= "□",
	[GEO_TYPE.SOLID] 				= "◼",
	[GEO_TYPE.SLOPE_RIGHT_UP] 		= "◢",
	[GEO_TYPE.SLOPE_LEFT_UP] 		= "◣",
	[GEO_TYPE.SLOPE_RIGHT_DOWN] 	= "◤",
	[GEO_TYPE.SLOPE_LEFT_DOWN] 		= "◥",
	[GEO_TYPE.FLOOR] 				= "▬",
	[GEO_TYPE.SHORTCUT_ENTRANCE] 	= "◬",
	[GEO_TYPE.GLASS] 				= "▣"
}


local OUTPUT_OBJECT = {
	VERTICAL_BEAM = 1,
	HORIZONTAL_BEAM = 2,
	SHORTCUT = 3,
	ENTRANCE = 4,
	CREATURE_DEN = 5,
	LAYER_2_WALL = 6,
	BAT_HIVE = 7,
	WATERFALL = 8,
	WHACK_A_MOLE_HOLE = 9,
	GARBAGE_WORM = 10,
	WORM_GRASS = 11,
	SCAVENGER_HOLE = 12
}

local OBJECT_TO_SPAWN_DATA_MAPPING = {
	[OBJECT_TYPE.VERTICAL_BEAM] 	= nil,
	[OBJECT_TYPE.HORIZONTAL_BEAM] 	= nil,
	[OBJECT_TYPE.SHORTCUT] 			= nil,
	[OBJECT_TYPE.ENTRANCE] 			= nil,
	[OBJECT_TYPE.CREATURE_DEN] 		= nil,
	[OBJECT_TYPE.HIVE] 				= nil,
	[OBJECT_TYPE.WATERFALL] 		= nil,
	[OBJECT_TYPE.WHACK_A_MOLE_HOLE] = nil,
	[OBJECT_TYPE.GARBAGE_WORM] 		= nil,
	[OBJECT_TYPE.WORM_GRASS] 		= nil,
	[OBJECT_TYPE.SCAVENGER_HOLE] 	= nil,
	[OBJECT_TYPE.NONE] 				= nil,
	[OBJECT_TYPE.ROCK] 				= 0,
	[OBJECT_TYPE.SPEAR] 			= 1,
	[OBJECT_TYPE.CRACK] 			= nil,
	[OBJECT_TYPE.FORBID_FLY_CHAIN] 	= nil
}

local OBJECT_TO_OUTPUT_MAPPING = {
	[OBJECT_TYPE.VERTICAL_BEAM] 	= OUTPUT_OBJECT.VERTICAL_BEAM,
	[OBJECT_TYPE.HORIZONTAL_BEAM] 	= OUTPUT_OBJECT.HORIZONTAL_BEAM,
	[OBJECT_TYPE.SHORTCUT] 			= OUTPUT_OBJECT.SHORTCUT,
	[OBJECT_TYPE.ENTRANCE] 			= OUTPUT_OBJECT.ENTRANCE,
	[OBJECT_TYPE.CREATURE_DEN] 		= OUTPUT_OBJECT.CREATURE_DEN,
	[OBJECT_TYPE.HIVE] 				= OUTPUT_OBJECT.BAT_HIVE,
	[OBJECT_TYPE.WATERFALL] 		= OUTPUT_OBJECT.WATERFALL,
	[OBJECT_TYPE.WHACK_A_MOLE_HOLE] = OUTPUT_OBJECT.WHACK_A_MOLE_HOLE,
	[OBJECT_TYPE.GARBAGE_WORM] 		= OUTPUT_OBJECT.GARBAGE_WORM,
	[OBJECT_TYPE.WORM_GRASS] 		= OUTPUT_OBJECT.WORM_GRASS,
	[OBJECT_TYPE.SCAVENGER_HOLE] 	= OUTPUT_OBJECT.SCAVENGER_HOLE,
	[OBJECT_TYPE.NONE] 				= nil,
	[OBJECT_TYPE.ROCK] 				= nil,
	[OBJECT_TYPE.SPEAR] 			= nil,
	[OBJECT_TYPE.CRACK] 			= nil,
	[OBJECT_TYPE.FORBID_FLY_CHAIN] 	= nil
}

local OBJECT_LOG_CHAR = {
	[OBJECT_TYPE.VERTICAL_BEAM] 	= '|',
	[OBJECT_TYPE.HORIZONTAL_BEAM] 	= '-',
	[OBJECT_TYPE.SHORTCUT] 			= '*',
	[OBJECT_TYPE.ENTRANCE] 			= '=',
	[OBJECT_TYPE.CREATURE_DEN] 		= 'D',
	[OBJECT_TYPE.HIVE] 				= 'H',
	[OBJECT_TYPE.WATERFALL] 		= '~',
	[OBJECT_TYPE.WHACK_A_MOLE_HOLE] = 'W',
	[OBJECT_TYPE.GARBAGE_WORM] 		= '$',
	[OBJECT_TYPE.WORM_GRASS] 		= 'G',
	[OBJECT_TYPE.SCAVENGER_HOLE] 	= '@',
	[OBJECT_TYPE.NONE] 				= ' ',
	[OBJECT_TYPE.ROCK] 				= '.',
	[OBJECT_TYPE.SPEAR] 			= '/',
	[OBJECT_TYPE.CRACK] 			= '#',
	[OBJECT_TYPE.FORBID_FLY_CHAIN] 	= 'F'
}

local function logAlert(message)
	if (not rained.isBatchMode()) then print(message) end
	rained.alert(message);
end

local function round(v)
	if (v > 0) then return math.floor(v + 0.5); end
	-- TODO: Floor or ceiling here?
	return math.floor(v + 0.5);
end

local function exportDocumentGeometry(light_angle, log_each_obj, log_each_geo)
	print("Geo Export: Start")

	--local light_angle = nil;

	if (log_each_obj == nil) then log_each_obj = false; end
	if (log_each_geo == nil) then log_each_geo = false; end

	if (not rained.isDocumentOpen()) then
		logAlert("Geo Export: No document selected!")
		return
	end


	local level = rained.level;

	if level == nil or level.name == nil then
		logAlert("Geo Export: No or invalid document selected!")
		return
	end

	print(("Geo Export: Level: %s"):format(level.name));

	local targetDirectory = path.join(rained.getDataDirectory(), "Levels");
	local targetFilePath = path.join(targetDirectory, level.name .. ".txt");
	print(("Geo Export: TargetDirectory: %s"):format(targetDirectory));

	local geometryFile = openFile(targetFilePath, "w")

	-- Line 1: Level name
	-- -- (Not read by the game, but is customary I suppose)
	geometryFile:write(("%s\n"):format(level.name));

	-- Line 2: [Level Width]*[Level Height]|[Water Level]|[Water In Front of Terrain]

	local levelPlayableWidth = level.width - (level.borderLeft + level.borderRight);
	local levelPlayableHeight = level.height - (level.borderTop + level.borderBottom);

	geometryFile:write(("%s*%s"):format(levelPlayableWidth, levelPlayableHeight));
	if (level.hasWater) then
		local inFront = 0;
		if (level.isWaterInFront) then
			inFront = 1;
		end
		geometryFile:write(("|%s|%s"):format(level.waterLevel, inFront));
	end
	geometryFile:write("\n")

	-- Line 3: 	[Light Angle X]*[Light Angle Y]|0|0
	if (light_angle == nil or light_angle.x == nil or light_angle.y == nil) then
		geometryFile:write(("0.0000*1.0000|0|0|Sorry you can't actually get the light angle in rained lua."));
	else
		geometryFile:write(("%s*%s"):format(light_angle.x, light_angle.y));
	end
	geometryFile:write("\n");

	-- Line 4: [Camera 1 x],[Camera 1 y]|[Camera 2 x],[Camera 2 y]|...
	-- Not sure if we need to be this distrustful of rained.cameras.getCameras...
	local camPositions = {};
	local cameras = rained.cameras.getCameras();

	for i = 1, #cameras do
		local camera = cameras[i];
		if (camera ~= nil and camera.x ~= nil and camera.y ~= nil) then
			local cPosition = getOutputCoord(level, camera);
			-- Convert from tile space to pixel space.
			cPosition.x = round(cPosition.x * 20);
			cPosition.y = round(cPosition.y * 20);
			table.insert(camPositions, cPosition);
		end
	end

	if (#camPositions <= 0) then
		print(("Geo Export: * Warning: No cameras found! (#cameras: %s)"):format(#cameras));
	else
		print(("Geo Export: * %s camera(s) found."):format(#camPositions));
	end

	for i = 1, #camPositions do
		geometryFile:write(("%s,%s"):format(camPositions[i].x, camPositions[i].y));
		if (i < #camPositions) then
			geometryFile:write("|");
		end
	end

	geometryFile:write("\n");

	-- Line 5: Unused
	geometryFile:write("Border: Maybe?\n");

	-- Line 6: Object Spawn Data
	print("Geo Export: * Writing object spawn data.");
	for x = level.borderLeft, level.borderLeft + levelPlayableWidth - 1 do
		for y = level.borderTop, level.borderTop + levelPlayableHeight - 1 do
			local objects = rained.cells.getObjects(x, y, 1)

			for i = 1, #objects do
				local obj = objects[i]
				local spawnObjectID = OBJECT_TO_SPAWN_DATA_MAPPING[obj];

				if (spawnObjectID ~= nil) then
					-- TODO: I'm not sure why this coordinate must be offset by one.
					local outPos = getOutputCoord(level, {x=(x + 1), y=(y+1)});
					local outText = ("%s,%s,%s|"):format(spawnObjectID, outPos.x, outPos.y);
					if (log_each_obj) then print(("Geo Export: * -- Object %s at (%s,%s) output as %s."):format(obj, x, y, outText)); end
					geometryFile:write(outText);
				end
			end
		end
	end

	geometryFile:write("\n");

	-- Line 7-11: Unused
	geometryFile:write("\n\n\n0\n\n");

	-- Line 12: Geometry data
	-- It's important to loop over these in Column-Major order
	print("Geo Export: * Writing geometry data.");
	for x = level.borderLeft, level.borderLeft + levelPlayableWidth - 1 do
		for y = level.borderTop, level.borderTop + levelPlayableHeight - 1 do
			-- We can embed comments to help troubleshooting.
			local comment = nil;
			local logText = "";

			if (y == level.borderTop) then
				comment = ("col %s"):format(x - level.borderLeft);
			end

			local cGeo = rained.cells.getGeo(x, y, 1);
			local cObjs = rained.cells.getObjects(x, y, 1);

			if (log_each_geo) then
				local geoLogAs = GEO_BOX_DRAWINGS[cGeo]
				if (geoLogAs == nil) then geoLogAs = "ERR" end;
				logText = geoLogAs .. ' - ';
			end

			-- Convert the saved data geo type to the output geo type. This is the first thing we'll output
			local outGeo = GEO_TO_OUTPUT_MAPPING[cGeo];

			-- The rest of the data goes in this table here.
			local output = {};

			-- This table tracks what output we've added.
			local hasOutput = {}

			-- Check whether each object on this tile needs to be included in the geo, and if so, the value it should be encoded as.
			for i = 1, #cObjs do
				local object = cObjs[i];
				local logObjAs = OBJECT_LOG_CHAR[object];
				if (log_each_geo and logObjAs ~= nil) then logText = logText .. logObjAs end

				local outputVal = OBJECT_TO_OUTPUT_MAPPING[object]

				-- Fissures are non-solid
				if (object == OBJECT_TYPE.CRACK) then
					outGeo = OUTPUT_GEO.AIR;
				end

				if (outputVal ~= nil) then
					table.insert(output, outputVal);
					hasOutput[outputVal] = true;
				end
			end

			-- Add shortcut objects to tiles with the shortcut geo type. TODO: Is this really necessary?
			if (outGeo == OUTPUT_GEO.SHORTCUT_ENTRANCE and not hasOutput[OUTPUT_OBJECT.SHORTCUT]) then
				table.insert(output, OUTPUT_OBJECT.SHORTCUT)
			end

			-- Get L2 solidity
			if (rained.cells.getGeo(x, y, 2) == GEO_TYPE.SOLID and outGeo ~= OUTPUT_GEO.SOLID) then
				table.insert(output, OUTPUT_OBJECT.LAYER_2_WALL);
				hasOutput[OUTPUT_OBJECT.LAYER_2_WALL] = true;
			end

			-- Sneak in a comment if we have one
			--[[if (comment ~= nil) then
				table.insert(output, comment);
			end--]]

			-- Write to file
			local outText = "";

			outText = outText .. ("%s"):format(outGeo);
			for i = 1, #output do
				outText = outText .. (",%s"):format(output[i]);
			end
			outText = outText .. "|";

			geometryFile:write(outText );
			if (log_each_geo) then print(("Geo Export: * -- (%s,%s) %s output as %s."):format(x, y, logText, outText)); end
		end
	end


	print("Geo Export: * Done writing geometry data.");

	geometryFile:write("\n");

	-- Line 13: Not parsed
	geometryFile:write("This file was created by the Export Level Geometry script for Rained.\n");

	geometryFile:close();

	logAlert("Geo Export: Done.");
end


--[[
rained.registerCommand({
	name="Export Geometry (lua)",
	callback=function() exportDocumentGeometry(nil, false, false) end,
	autoHistory=false,
	requiresLevel=true
})
--]]

rained.gui.menuHook('File', function()
	if(imgui.MenuItem_Bool("Export Geometry (lua)")) then
		local status, err = pcall(function() exportDocumentGeometry(nil, false, false) end)
		if (not status) then
			logAlert(("Geo Export: FAILURE! %s"):format(err))
		end
	end
end
)

	--[[
do

	if (rained.isBatchMode() and not rained.isDocumentOpen()) then
		local levelPath = path.join(rained.getDataDirectory(), 'LevelEditorProjects','SB_B01_TEST.rwlz');
		rained.openLevel(levelPath);
	end
	exportDocumentGeometry(nil, true, true);
end--]]
