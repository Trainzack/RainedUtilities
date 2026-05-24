
if rained.isBatchMode() then return end

local path = require("path")
local imgui = require("imgui")

local show_tile_search = true

local search_settings = {
	width = {
		name = "Tile Width",
		min = 1,
		max = 10,
		max_max = math.huge,
	},
	height = {
		name = "Tile Height",
		min = 1,
		max = 10,
		max_max = math.huge,
	},
	depth = {
		name = "Tile Depth",
		min = 1,
		max = 2,
		max_max = 2,
	},
	--TODO set specs to nil
	--specs ={{5, 5, 1, 1}, width=2, height=2},
	specs = nil,
	include_l2_geo = false,
	change = true,
}

search_settings.params = {search_settings.width, search_settings.height, search_settings.depth}

local results = {
	count_tiles_checked = 0,
	tiles_matched = {},
	tiles_matched_names = {},
	count_tiles_excluded = 0,

}

local all_tiles = nil


local function setupTiles()

	print("Tile Search: Begin Setup Tiles")
	all_tiles = {}
	-- TODO: Why do tile methods fail?
	local cats = rained.props.getTileAsPropCategories()

	for i=1, #cats do
		--print(("---> Category: %s"):format(cats[i]))

		local tile_names = rained.props.getPropsInTileCategory(cats[i])

		for j=1, #tile_names do

			local tile = rained.tiles.getTileInfo(tile_names[j])
			table.insert(all_tiles, tile)
		end
	end

	print(("Tile Search: Got %s tiles."):format(#all_tiles))

end


local function getResults()

	if (all_tiles == nil) then setupTiles() end

	results.count_tiles_checked = 0
	results.tiles_matched = {}
	--results.tiles_matched_names = {}
	results.count_tiles_excluded = 0

	for i=1, #all_tiles do

		results.count_tiles_checked = results.count_tiles_checked + 1
		local matches = true

		local tile = all_tiles[i]

		local log = false; --(tile.name == "Grill Round")

		local t_depth = 1
		if (tile.specs2 ~= nil) then t_depth = 2 end

		local check_specs = (search_settings.specs ~= nil)

		if (check_specs) then
			if (tile.width ~= search_settings.specs.width
				or tile.height ~= search_settings.specs.height
				or t_depth ~= #search_settings.specs
			) then matches = false end
		else
			if (
				tile.width > search_settings.width.max
				or tile.width < search_settings.width.min
				or tile.height > search_settings.height.max
				or tile.height < search_settings.height.min
				or t_depth > search_settings.depth.max
				or t_depth < search_settings.depth.min
			) then matches = false end
		end

		if (log) then print(("Tile Search -- %s meets criteria? %s"):format(tile.name, matches)) end

		-- If we need to check the specs, then we'll need to compare specs one by one.
		if (check_specs and matches) then
			local tile_specs = {tile.specs, tile.specs2}
			for layer=1, #search_settings.specs do
				for i = 1, #search_settings.specs[layer] do
					local tile_geo = tile_specs[layer][i]
					-- Compare the tile specs to the search specs. If tile says -1, then we don't care what the search specs are.
					if (log) then print(("Geo at %s: %s"):format(i, tile_geo)) end
					if (tile_geo ~= -1) then
						if (tile_geo ~= search_settings.specs[layer][i]) then
							matches = false
						end
					end
				end
			end
		end


		if (matches) then
			table.insert(results.tiles_matched, tile)
			--table.insert(results.tiles_matched_names, tile.name)
		else
			results.count_tiles_excluded = results.count_tiles_excluded + 1
		end


	end

end


-- Ensure that the end statement is *always* run, even if we raise an error also.
local function protectedBegin(begin, inner, catch, finally, always_end)
	local s, p_open = begin()
	if (s) then
		local status, err = pcall(inner, p_open)
		finally()
		if (not status) then
			print(err)
			if (catch) then
				catch(err)
			else
				error(err)
			end
		end
	elseif (always_end) then
		finally()
	end
	return s
end
--[[
local function handleConfigTable()

	local change = false

	local columnFlags = imgui.TableColumnFlags_WidthStretch | imgui.TableColumnFlags_NoResize | imgui.TableColumnFlags_NoSort;
	imgui.TableSetupColumn("Parameter", columnFlags, 60);
	imgui.TableSetupColumn("Minimum", columnFlags, 50);
	imgui.TableSetupColumn("Maximum", columnFlags, 50);
	imgui.TableHeadersRow();
-- 					imgui.TableHeader("Parameter");
-- 					imgui.TableNextColumn();
-- 					imgui.TableHeader("Minimum");
-- 					imgui.TableNextColumn();
-- 					imgui.TableHeader("Maximum");
-- 					imgui.TableNextColumn();

	for i = 1, #search_settings.params do
		local param = search_settings.params[i]
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text(param.name);
		imgui.TableNextColumn();

		imgui.PushItemWidth(-0.00001);
		local _a, new_min = imgui.InputFloat(("Control Min %s"):format(param.name), param.min, 1, 5, "%.0f")
		imgui.PopItemWidth();
		imgui.TableNextColumn();

		imgui.PushItemWidth(-0.00001);
		local _b, new_max = imgui.InputFloat(("Control Max %s"):format(param.name), param.max, 1, 5, "%.0f")
		imgui.PopItemWidth();

		local min_changed = new_min ~= param.min;
		local max_changed = new_max ~= param.max;

		if (min_changed) then
			param.min = new_min
			param.max = math.max(new_min, param.max)
			change = true
		end
		if (max_changed) then
			param.max = new_max
			param.min = math.min(new_max, param.min)
			change = true
		end

		param.min = math.min(param.max_max, math.max(1, param.min))
		param.max = math.min(param.max_max, math.max(1, param.max))

	end

	return change

end
--]]

local box_drawings = {
	--[[,
    GEO_TYPE.AIR = "□",
    GEO_TYPE.SOLID = "◼",
    GEO_TYPE.SLOPE_RIGHT_UP = "◢",
    GEO_TYPE.SLOPE_LEFT_UP = "◣",
    GEO_TYPE.SLOPE_RIGHT_DOWN = "◤",
    GEO_TYPE.SLOPE_LEFT_DOWN = "◥",
    GEO_TYPE.FLOOR = "▬",
    GEO_TYPE.SHORTCUT_ENTRANCE = "◬",
    GEO_TYPE.GLASS = "▣"]]
}
box_drawings[-1] = " "
box_drawings[GEO_TYPE.AIR] = "[ ]";
box_drawings[GEO_TYPE.SOLID] = "MM";
box_drawings[GEO_TYPE.SLOPE_RIGHT_UP] = "[\\";
box_drawings[GEO_TYPE.SLOPE_LEFT_UP] = "/]";
box_drawings[GEO_TYPE.SLOPE_RIGHT_DOWN] = "[/";
box_drawings[GEO_TYPE.SLOPE_LEFT_DOWN] = "\\]";
box_drawings[GEO_TYPE.FLOOR] = "==";
box_drawings[GEO_TYPE.SHORTCUT_ENTRANCE] = "^";
box_drawings[GEO_TYPE.GLASS] = "00";

local function get_geo_symbol(geo)
	if (box_drawings[geo]) then return box_drawings[geo] end
	return "?"
end

local function handleSpecsTable()

	assert(search_settings.specs ~= nil)

	-- Whether to show a second layer
	local do_l2 = (#search_settings.specs > 1)

	local column_count = search_settings.specs.width
	local row_count = search_settings.specs.height

	local column_width = 20
	if (do_l2) then column_width = 50 end
	--print(("Specs Table: (%s x %s)"):format(column_count, row_count))

	local columnFlags = imgui.TableColumnFlags_WidthFixed | imgui.TableColumnFlags_NoResize | imgui.TableColumnFlags_NoSort;


	imgui.TableSetupColumn("", columnFlags, 20);
	for c=1, column_count do
		imgui.TableSetupColumn(("%s"):format(c), columnFlags, column_width);
	end

	imgui.TableHeadersRow();

	for r=1, row_count do
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text(("%s"):format(r))
		--imgui.TextUnformatted(("%s"):format(r), ("%s"):format(r));
		for c=1, column_count do
			local curIndex = ((c-1) * row_count) + r
			imgui.TableNextColumn();
			local cell_text = ""

			if (do_l2) then
				cell_text = ("%s (%s)"):format(get_geo_symbol(search_settings.specs[1][curIndex]), get_geo_symbol(search_settings.specs[2][curIndex]))
			else
				cell_text = ("%s"):format(get_geo_symbol(search_settings.specs[1][curIndex]))
			end

			imgui.Text(cell_text);
		end
	end

end



local function selectTile(tile)

	local targetFile = path.join(rained.getDataDirectory(), 'LevelEditorProjects', "tile_search_preview")

	for i = 1, rained.getDocumentCount() do
		if (rained.getDocumentName(i) == "tile_search_preview") then rained.closeDocument(i) end
	end

	local width = (tile.width + 1) * 3 + 24
	local height = (tile.height + 1) * 3 + 8
	rained.newLevel(width, height, targetFile)
	rained.tiles.placeTile(tile.name, width // 2, height // 2, 1, "geometry")
	rained.view.viewX = ((width // 2) - (tile.width / 2)) * 20
	rained.view.viewY = ((height // 2) - (tile.height / 2)) * 20
	rained.view.viewZoom = 5.0
end

local function handleResultsTable()

	local columnFlags = imgui.TableColumnFlags_WidthStretch | imgui.TableColumnFlags_NoResize | imgui.TableColumnFlags_NoSort;
	imgui.TableSetupColumn("Category", columnFlags, 60);
	imgui.TableSetupColumn("Tile", columnFlags, 120);
	imgui.TableSetupColumn("Size", columnFlags, 25);
	imgui.TableHeadersRow();

	for i = 1, #results.tiles_matched do
		local tile = results.tiles_matched[i]

		imgui.TableNextRow();
		imgui.TableNextColumn(); imgui.Text(tile.category);
		imgui.TableNextColumn();
		local s, selected = imgui.Selectable_BoolPtr(tile.name,false)

		local t_depth = 1; if (tile.specs2 ~= nil) then t_depth = 2; end
		imgui.TableNextColumn(); imgui.Text(("(%s x %s) [%s]"):format(tile.width, tile.height, t_depth));

		if (selected) then
			selectTile(tile)
		end
	end
end

--[[
local function updateTileSearch()

	if (not show_tile_search) then return end

	local close_button = false
	protectedBegin(
		function() return imgui.Begin("Tile Search", show_tile_search) end,
		function(p_open)
			show_tile_search = p_open

			local any_changes = search_settings.change;
			search_settings.change = false;

			protectedBegin(
				function() return imgui.BeginTable("Tile Search Controls", 3) end,
				function() if (handleConfigTable()) then any_changes = true end; end,
				nil,
				function() return imgui.EndTable() end, false
			)

			if (search_settings.specs == nil) then
				imgui.Text("No specs are loaded.");
				return;
			else
				protectedBegin(
					function() return imgui.BeginTable("Cell Specs", search_settings.specs.width + 1) end,
					function() handleSpecsTable() end,
					nil,
					function() return imgui.EndTable() end, false
				)
			end

			if (any_changes) then getResults() end

			imgui.Text(("Matches: %s / %s"):format(#results.tiles_matched, results.count_tiles_checked));
			--imgui.Text(("-- Matches: %s"):format());
			--imgui.Text(("-- Exclusions: %s"):format(results.count_tiles_excluded));

			protectedBegin(
				function() return imgui.BeginTable("Tile Search Results", 5, imgui.TableFlags_ScrollY) end,
				function()
					handleResultsTable()
				end,
				nil,
				function() return imgui.EndTable() end, true
			)

			--_r, new_selection_index, new_selection_name = imgui.ListBox("Results", 0, results.tiles_matched_names, #results.tiles_matched_names)

		end,
		function(err)
			print(("Tile Search: Ran into error [%s]. I'm closing the search window to avoid crashing Rained."):format(err))
			rained.alert("Tile Search crashed D:")
			show_tile_search = false
		end,
		function() return imgui.End() end, true
	)
end

rained.gui.menuHook('Tools', function()
	if(imgui.MenuItem_Bool("Tile Search")) then
		show_tile_search = not show_tile_search
		if (show_tile_search) then
			setupTiles()
		end
	end
end
)

rained.onUpdate(updateTileSearch);
--]]
local autotile = rained.tiles.createAutotile("Tile Search Geometry", "Utilities")


autotile.type = "rect"
autotile.autoHistory = false
autotile.uiHook = function()
	imgui.TextWrapped("Select a region, and the Tile Search will update to only include tiles that exactly fit the geometry in the selected region.")

	s, search_settings.include_l2_geo = imgui.Checkbox("Include Layer Behind", search_settings.include_l2_geo)

	local function handle_error(err)
		print(("Tile Search: Ran into error [%s]. I'm clearing the search results to avoid crashing Rained."):format(err))
		rained.alert("Tile Search crashed D:")
		search_settings.specs = nil
	end

	if (search_settings.specs == nil) then
		imgui.Text("No specs are loaded.");
		return;
	else
		protectedBegin(
			function() return imgui.BeginTable("Cell Specs", search_settings.specs.width + 1) end,
			function() handleSpecsTable() end,
			handle_error,
			function() return imgui.EndTable() end, false
		)
	end

	if (search_settings.change) then
		getResults()
		search_settings.change = false;
	end

	imgui.Text(("Matches: %s / %s"):format(#results.tiles_matched, results.count_tiles_checked));

	protectedBegin(
		function() return imgui.BeginTable("Tile Search Results", 5, imgui.TableFlags_ScrollY) end,
		function()
			handleResultsTable()
		end,
		handle_error,
		function() return imgui.EndTable() end, false
	)

end

function autotile:tileRect(layer, left, top, right, bottom, forceModifier)

	-- If we've selected l2 geometery, and there's geometery there to select, then try to select l2 geometry.
	local do_l2 = (search_settings.include_l2_geo and layer < 3)
	search_settings.specs = {}
	search_settings.specs[1] = {}
	if (do_l2) then
		search_settings.specs[2] = {}
	else
		search_settings.specs[2] = nil
	end

	search_settings.specs.width = (right-left) + 1
	search_settings.specs.height = (bottom-top) + 1

	local max_layer = layer
	if (do_l2) then max_layer = layer + 1 end

	-- Iterate over the geometery in the selection, and copy that into our search specs.
	for l = layer, max_layer do
		for x=left, right do

			for y=top, bottom do
				local cell_geo = rained.cells.getGeo(x, y, layer)

				-- Tiles can't be shortcut entrances, so any tile will have to just not care here.
				if (cell_geo == GEO_TYPE.SHORTCUT_ENTRANCE) then cell_geo = -1 end
				table.insert(search_settings.specs[l], cell_geo)

			end
		end
	end
	search_settings.change = true;
end
