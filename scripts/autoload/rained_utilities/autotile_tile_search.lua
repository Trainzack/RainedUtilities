
if rained.isBatchMode() then return end

local path = require("path")
local imgui = require("imgui")

local show_tile_search = true

local SELECTION_MODE = {
	TILE_FITS_IN_RECT = 1,
	TILE_MATCHES_RECT = 2,
	RECT_FITS_IN_TILE = 3
}

local search_settings = {
	-- If we have a search: A table containing tables of numbers. Each table should match the specs array of the search region.
	-- There will be one specs table if we're searching one level, and two specs tables if we're searching two levels.
	specs = nil,

	-- User settings
	include_l2_geo = false,
	selection_mode = SELECTION_MODE.TILE_MATCHES_RECT,

	-- Records whether there's a change that will require us to do a search
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

	print(("Tile Search: Selecting tile '%s'"):format(tile.name))

	local targetFile = path.join(rained.getDataDirectory(), 'LevelEditorProjects', "tile_search_preview")

	for i = 1, rained.getDocumentCount() do
		if (rained.getDocumentName(i) == "tile_search_preview") then
			rained.closeDocument(i)
			-- We must break to avoid crashing rained by checking an invalid document.
			break;
		end
	end


	local width = (tile.width + 1) * 3 + 24
	local height = (tile.height + 1) * 3 + 8

	local tile_center_pos = {x= width // 2, y= height // 2}
	local tile_top_left = {x= tile_center_pos.x - tile.centerX, y= tile_center_pos.y - tile.centerY}


	--print("Tile Search: Opening new level")
	rained.newLevel(width, height, targetFile)

	--[[
	print("Tile Search: Placing background glass")
	-- Place some tiles in the background to frame the tile.
	for x = tile_top_left.x - 1, tile_top_left.x + tile.width do
		for y = tile_top_left.y - 1, tile_top_left.y + tile.height do
			rained.cells.setGeo(x, y, 1, GEO_TYPE.GLASS)
		end
	end
	--]]

	--print("Tile Search: Placing tile")
	rained.tiles.placeTile(tile.name, tile_center_pos.x, tile_center_pos.y, 1, "geometry")


	--print("Tile Search: Centering camera")
	rained.view.viewX = (tile_top_left.x - 2) * 20
	rained.view.viewY = (tile_top_left.y - 2) * 20
	rained.view.viewZoom = 5.0

	print(("Tile Search: Done selecting tile '%s'"):format(tile.name))
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

	imgui.SeparatorText("Specs");
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

	imgui.SeparatorText("Results");
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
				table.insert(search_settings.specs[l - layer + 1], cell_geo)

			end
		end
	end
	search_settings.change = true;
end
