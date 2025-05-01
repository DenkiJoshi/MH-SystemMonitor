---@diagnostic disable: undefined-global

-- local ui_scale = 1; -- 1920x1080
local ui_scale = math.sqrt(2); -- 3840x2160

local ui_position = {
    x = 150,
	y = 40,
	anchor = "bottom-left" -- top-left, top-middle, top-right, center-left, center-middle, center-right, bottom-left, bottom-middle, bottom-right
};

local spacing = {
    x = 195,
	y = 0,
};

local name_label = {
	visibility = true,

	settings = {
		right_alignment_shift = 0
	},

	text_formatting = "%s",

	offset = {
		x = 5,
		y = 0
	},

	color = 0xFFCCF4E1,

	shadow = {
		visibility = true,

		offset = {
			x = 1,
			y = 1
		},

		color = 0xFF000000
	}
};

local value_label = {
	visibility = true,

	settings = {
		right_alignment_shift = 0
	},

	text_formatting = "%s", -- current_health/max_health

	include = {
		current_value = true,
		max_value = true
	},

	offset = {
		x = 5,
		y = 17
	},

	color = 0xFFFFFFFF,

	shadow = {
		visibility = true,

		offset = {
			x = 1,
			y = 1
		},

		color = 0xFF000000
	}
};

local percentage_label = {
	visibility = true,

	settings = {
		right_alignment_shift = 6
	},

	text_formatting = "%.1f%%",

	offset = {
		x = 125,
		y = 17
	},

	color = 0xFFFFFFFF,

	shadow = {
		visibility = true,

		offset = {
			x = 1,
			y = 1
		},

		color = 0xFF000000
	}
};

local bar = {
	visibility = true,

	settings = {
		fill_direction = "Left to Right"
	},

	offset = {
		x = 0,
		y = 15
	},

	size = {
		width = 175,
		height = 20
	},

	outline = {
		visibility = true,
		thickness = 1, -- doesn't work, needs d2d implementation
		offset = 0,
		style = "Center"
	},

	colors = {
		foreground = 0xB974A653,
		background = 0xB9000000,
		outline = 0xC0000000
	},
};

local mod_name = "Health Bars";
local version = "v0.1.1";
local versioned_mod_name = string.format("%s %s", mod_name, version);

local epsilon = 0.000001;
local is_enabled = true;
local is_imgui_window_opened = false;

local function table_is_empty(table_)
	return next(table_) == nil;
end

local function table_tostring(table_)
	if type(table_) == "number" or type(table_) == "boolean" or type(table_) == "string" then
		return tostring(table_);
	end

	if table_is_empty(table_) then
		return "{}";
	end

	local cache = {};
	local stack = {};
	local output = {};
	local depth = 1;
	local output_str = "{\n";

	while true do
		local size = 0;
		for k,v in pairs(table_) do
			size = size + 1;
		end

		local cur_index = 1;
		for k,v in pairs(table_) do
			if cache[table_] == nil or cur_index >= cache[table_] then

				if string.find(output_str, "}", output_str:len()) then
					output_str = output_str .. ",\n";
				elseif not string.find(output_str, "\n", output_str:len()) then
					output_str = output_str .. "\n";
				end

				-- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
				table.insert(output,output_str);
				output_str = "";

				local key;
				if type(k) == "number" or type(k) == "boolean" then
					key = "[" .. tostring(k) .. "]";
				else
					key = "['" .. tostring(k) .. "']";
				end

				if type(v) == "number" or type(v) == "boolean" then
					output_str = output_str .. string.rep('\t', depth) .. key .. " = "..tostring(v);
				elseif type(v) == "table" then
					output_str = output_str .. string.rep('\t', depth) .. key .. " = {\n";
					table.insert(stack, table_);
					table.insert(stack, v);
					cache[table_] = cur_index + 1;
					break;
				else
					output_str = output_str .. string.rep('\t', depth) .. key .. " = '" .. tostring(v) .. "'";
				end

				if cur_index == size then
					output_str = output_str .. "\n" .. string.rep('\t', depth - 1) .. "}";
				else
					output_str = output_str .. ",";
				end
			else
				-- close the table
				if cur_index == size then
					output_str = output_str .. "\n" .. string.rep('\t', depth - 1) .. "}";
				end
			end

			cur_index = cur_index + 1;
		end

		if size == 0 then
			output_str = output_str .. "\n" .. string.rep('\t', depth - 1) .. "}";
		end

		if #stack > 0 then
			table_ = stack[#stack];
			stack[#stack] = nil;
			depth = cache[table_] == nil and depth + 1 or depth - 1;
		else
			break;
		end
	end

	-- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
	table.insert(output, output_str);
	output_str = table.concat(output);

	return output_str;
end

local function number_is_equal(value1, value2)
	if math.abs(value1 - value2) < epsilon then
		return true;
	end

	return false;
end

local scene_manager_type_def = sdk.find_type_definition("via.SceneManager");

local scene_view_type = sdk.find_type_definition("via.SceneView");
local get_size_method = scene_view_type:get_method("get_Size");

local size_type = get_size_method:get_return_type();
local width_field = size_type:get_field("w");
local height_field = size_type:get_field("h");


local function get_game_window_size()
	local scene_manager = sdk.get_native_singleton("via.SceneManager");
	if scene_manager == nil then
		return 1920, 1080;
	end

	local scene_view = sdk.call_native_func(scene_manager, scene_manager_type_def, "get_MainView");
	if scene_view == nil then
		return 1920, 1080;
	end

	local size = get_size_method:call(scene_view);
	if size == nil then
		return 1920, 1080;
	end

	local screen_width = width_field:get_data(size);
	if screen_width == nil then
		return 1920, 1080;
	end

	local screen_height = height_field:get_data(size);
	if screen_height == nil then
		return 1920, 1080;
	end

	return screen_width, screen_height;
end

local function argb_color_to_abgr_color(argb_color)
	local alpha = (argb_color >> 24) & 0xFF;
	local red = (argb_color >> 16) & 0xFF;
	local green = (argb_color >> 8) & 0xFF;
	local blue = argb_color & 0xFF;

	local abgr_color = 0x1000000 * alpha + 0x10000 * blue + 0x100 * green + red;

	return abgr_color;
end

local function draw_label(label, position, ...)
	if label == nil or not label.visibility then
		return;
	end

	local text = string.format(label.text_formatting, table.unpack({ ... }));

	if text == "" then
		return;
	end

	local right_alignment_shift = label.settings.right_alignment_shift;

	if right_alignment_shift ~= 0 then
		local right_alignment_format = string.format("%%%ds", right_alignment_shift);
		text = string.format(right_alignment_format, text);
	end

	local position_x = position.x + label.offset.x;
	local position_y = position.y + label.offset.y;

	if label.shadow.visibility then
		local new_shadow_color = label.shadow.color;

		new_shadow_color = argb_color_to_abgr_color(new_shadow_color);
		draw.text(text, position_x + label.shadow.offset.x, position_y + label.shadow.offset.y, new_shadow_color);
	end

	local new_color = argb_color_to_abgr_color(label.color);
	
	draw.text(text, position_x, position_y, new_color);
end

local function draw_bar(bar, position, percentage)
    if bar == nil or not bar.visibility then
        return;
    end

    if percentage > 1 then
        percentage = 1;
    end

    if percentage < 0 then
        percentage = 0;
    end

    local outline_visibility = bar.outline.visibility;
    local style = bar.outline.style;                 -- Inside/Center/Outside
    local fill_direction = bar.settings.fill_direction; -- Left to Right/Right to Left/Top to Bottom/Bottom to Top

    local outline_thickness = bar.outline.thickness;
    if not outline_visibility then
        outline_thickness = 0;
    end

    local half_outline_thickness = outline_thickness / 2;

    local outline_offset = bar.outline.offset;

    if number_is_equal(outline_thickness, 0) then
        outline_offset = 0;
    end

    local half_outline_offset = outline_offset / 2;

    local outline_position_x = 0;
    local outline_position_y = 0;

    local outline_width = 0;
    local outline_height = 0;

    local position_x = 0;
    local position_y = 0;

    local width = 0;
    local height = 0;

    local foreground_width = 0;
    local foreground_height = 0;

    local background_width = 0;
    local background_height = 0;

    local foreground_shift_x = 0;
    local foreground_shift_y = 0;

    local background_shift_x = 0;
    local background_shift_y = 0;

    if style == "Inside" then
        outline_position_x = position.x + bar.offset.x + half_outline_thickness;
        outline_position_y = position.y + bar.offset.y + half_outline_thickness;

        outline_width = bar.size.width - outline_thickness;
        outline_height = bar.size.height - outline_thickness;

        position_x = outline_position_x + half_outline_thickness + outline_offset;
        position_y = outline_position_y + half_outline_thickness + outline_offset;

        width = outline_width - outline_thickness - outline_offset - outline_offset;
        height = outline_height - outline_thickness - outline_offset - outline_offset;
    elseif style == "Center" then
        outline_position_x = position.x + bar.offset.x - half_outline_offset;
        outline_position_y = position.y + bar.offset.y - half_outline_offset;

        outline_width = bar.size.width + outline_offset;
        outline_height = bar.size.height + outline_offset;

        position_x = outline_position_x + half_outline_thickness + outline_offset;
        position_y = outline_position_y + half_outline_thickness + outline_offset;

        width = outline_width - outline_thickness - outline_offset - outline_offset;
        height = outline_height - outline_thickness - outline_offset - outline_offset;
    else -- Outside
        position_x = position.x + bar.offset.x;
        position_y = position.y + bar.offset.y;

        width = bar.size.width;
        height = bar.size.height;

        outline_position_x = position_x - half_outline_thickness - outline_offset;
        outline_position_y = position_y - half_outline_thickness - outline_offset;

        outline_width = width + outline_thickness + outline_offset + outline_offset;
        outline_height = height + outline_thickness + outline_offset + outline_offset;
    end

    if fill_direction == "Right to Left" then
        foreground_width = width * percentage;
        foreground_height = height;

        background_width = width - foreground_width;
        background_height = height;

        foreground_shift_x = background_width;
    elseif fill_direction == "Top to Bottom" then
        foreground_width = width;
        foreground_height = height * percentage;

        background_width = width;
        background_height = height - foreground_height;

        background_shift_y = foreground_height;
    elseif fill_direction == "Bottom to Top" then
        foreground_width = width;
        foreground_height = height * percentage;

        background_width = width;
        background_height = height - foreground_height;

        foreground_shift_y = background_height;
    else -- Left to Right
        foreground_width = width * percentage;
        foreground_height = height;

        background_width = width - foreground_width;
        background_height = height;

        background_shift_x = foreground_width;
    end

    local foreground_color = bar.colors.foreground;
    local background_color = bar.colors.background;
    local outline_color = bar.colors.outline;

    -- background
    if background_width ~= 0 then
        background_color = argb_color_to_abgr_color(background_color);
        draw.filled_rect(position_x + background_shift_x, position_y + background_shift_y, background_width,
            background_height, background_color);
    end
    -- foreground
    if foreground_width ~= 0 then
        foreground_color = argb_color_to_abgr_color(foreground_color);
        draw.filled_rect(position_x + foreground_shift_x, position_y + foreground_shift_y, foreground_width,
            foreground_height, foreground_color);
    end

    -- outline
    if outline_thickness ~= 0 then
        outline_color = argb_color_to_abgr_color(outline_color);
        draw.outline_rect(outline_position_x, outline_position_y, outline_width, outline_height, outline_color);
    end
end

local function scale_ui()
    ui_position.x = ui_position.x * ui_scale;
    ui_position.y = ui_position.y * ui_scale;
	
    spacing.x = spacing.x * ui_scale;
	spacing.y = spacing.y * ui_scale;

    local labels = { name_label, value_label, percentage_label };

	for _, label in ipairs(labels) do
		label.offset.x = label.offset.x * ui_scale;
        label.offset.y = label.offset.y * ui_scale;
        label.shadow.offset.x = label.shadow.offset.x * ui_scale;
		label.shadow.offset.y = label.shadow.offset.y * ui_scale;
	end

    bar.offset.x = bar.offset.x * ui_scale;
	bar.offset.y = bar.offset.y * ui_scale;
    bar.size.width = bar.size.width * ui_scale;
	bar.size.height = bar.size.height * ui_scale;
    bar.outline.offset = bar.outline.offset * ui_scale;
    bar.outline.thickness = bar.outline.thickness * ui_scale;
end

local function anchor_ui()
	local screen_width, screen_height = get_game_window_size();

    local anchored_ui_position = {
        x = ui_position.x,
		y = ui_position.y,
	};

    if ui_position.anchor == "top-left" then
		return anchored_ui_position;
	end

    if ui_position.anchor == "top-middle" then
        anchored_ui_position.x = anchored_ui_position.x + (screen_width / 2);

        return anchored_ui_position;
    end
	
    if ui_position.anchor == "top-right" then
        anchored_ui_position.x =  screen_width - anchored_ui_position.x;

        return anchored_ui_position;
    end
	
	if ui_position.anchor == "center-left" then
        anchored_ui_position.y = (screen_height / 2) + anchored_ui_position.y;

        return anchored_ui_position;
    end

	if ui_position.anchor == "center-middle" then
        anchored_ui_position.x = (screen_width / 2) + anchored_ui_position.x;
        anchored_ui_position.y = (screen_height / 2) + anchored_ui_position.y;

        return anchored_ui_position;
    end

    if ui_position.anchor == "center-right" then
        anchored_ui_position.x = screen_width - anchored_ui_position.x;
        anchored_ui_position.y = (screen_height / 2) - anchored_ui_position.y;

        return anchored_ui_position;
    end

    if ui_position.anchor == "bottom-left" then
        anchored_ui_position.y = screen_height - anchored_ui_position.y;

        return anchored_ui_position;
    end

    if ui_position.anchor == "bottom-middle" then
        anchored_ui_position.x = (screen_width / 2) + anchored_ui_position.x;
        anchored_ui_position.y = screen_height - anchored_ui_position.y;

        return anchored_ui_position;
    end

    if ui_position.anchor == "bottom-right" then
        anchored_ui_position.x = screen_width - anchored_ui_position.x;
        anchored_ui_position.y = screen_height - anchored_ui_position.y;

        return anchored_ui_position;
    end
end

local enemy_context_type_def = sdk.find_type_definition("app.cEnemyContext");
local get_is_angry_method = enemy_context_type_def:get_method("get_IsAngry");
local get_is_boss_method = enemy_context_type_def:get_method("get_IsBoss");
local get_browser_method = enemy_context_type_def:get_method("get_Browser");
local get_em_id_method = enemy_context_type_def:get_method("get_EmID");
local get_role_id_method = enemy_context_type_def:get_method("get_RoleID");
local get_legendary_id_method = enemy_context_type_def:get_method("get_LegendaryID");

local enemy_browser_type_def = get_browser_method:get_return_type();
local context_field = enemy_browser_type_def:get_field("_Context");

local enemy_context_holder_type_def = context_field:get_type();
local get_chara_method = enemy_context_holder_type_def:get_method("get_Chara");


local enemy_character_context_type_def = get_chara_method:get_return_type();
local get_health_manager_method = enemy_character_context_type_def:get_method("get_HealthManager");

local health_manager_type_def = get_health_manager_method:get_return_type();
local get_health_method = health_manager_type_def:get_method("get_Health");
local get_max_health_method = health_manager_type_def:get_method("get_MaxHealth");

local enemy_def_type_def = sdk.find_type_definition("app.EnemyDef");
local name_string_method = enemy_def_type_def:get_method("NameString");

local bosses = {};

local function on_update(enemy_context)
	if not is_enabled then
		return;
	end

	if enemy_context == nil then
		return;
	end

	local boss = bosses[enemy_context];

	if (boss == nil) then
		local is_boss = get_is_boss_method:call(enemy_context);
		if is_boss == nil or not is_boss then
			return;
		end

		local browser = get_browser_method:call(enemy_context);
		if browser == nil then
			return;
		end

		local context_holder = context_field:get_data(browser);
		if context_holder == nil then
			return;
		end

		local character_context = get_chara_method:call(context_holder);
		if character_context == nil then
			return;
		end

		local health_manager = get_health_manager_method:call(character_context);
		if health_manager == nil then
			return;
		end
		
		local em_id = get_em_id_method:call(enemy_context);
        if em_id == nil then
            return;
        end
		
		local role_id = get_role_id_method:call(enemy_context);
        if role_id == nil then
            return;
        end
		
		local legendary_id = get_legendary_id_method:call(enemy_context);
        if legendary_id == nil then
            return;
        end

		local name = name_string_method:call(nil, em_id, role_id, legendary_id);
		if name == nil then
			return;
		end
		
		boss = {
			em_id = em_id,
			role_id = role_id,
			legendary_id = legendary_id,
			name = name,
			health_manager = health_manager,
			health = -1,
            max_health = -1,
            health_percentage = -1,
			last_update_time_s = 0
		};
	end

	

    local health = get_health_method:call(boss.health_manager);
	if health == nil or number_is_equal(health, 0) then
		return;
	end

	local max_health = get_max_health_method:call(boss.health_manager);
	if max_health == nil then
		return;
	end
	
	boss.health = health;
    boss.max_health = max_health;
	boss.health_percentage = health / max_health;
    boss.last_update_time_s = os.clock();
	
	bosses[enemy_context] = boss;
end

sdk.hook(get_is_angry_method, function(args)
    local enemy_context = sdk.to_managed_object(args[2]);
	
	local success, error = pcall(on_update, enemy_context);
	if not success then
		log.debug(error);
	end
end, function(return_value)
	return return_value;
end)

local function on_draw_imgui_window()
    if not is_imgui_window_opened then
        return;
    end
	
	is_imgui_window_opened = imgui.begin_window(
		string.format("%s##HEALTH_BARS", versioned_mod_name),
		is_imgui_window_opened,
		0x10120);

    if not is_imgui_window_opened then
        imgui.end_window();
        return;
    end
	
    imgui.text("Author: ");
    imgui.same_line();
    imgui.text_colored("GreenComfyTea", 0xFF80ff80);
	
    imgui.new_line();
    imgui.text("If you like the mod, please consider making a small donation!");
    imgui.text("It would help me develop a fully featured overlay in the future!");
end

local function on_frame()
    if not is_enabled then
        return;
    end
	
	on_draw_imgui_window();

    local anchored_ui_position = anchor_ui();

    local removalList = {};
	local displayList = {};
    local current_time_s = os.clock();

    for enemy_context_holder, boss in pairs(bosses) do
        if number_is_equal(boss.health, 0) then
            table.insert(removalList, enemy_context_holder);
			goto continue;
		end

        if (current_time_s - boss.last_update_time_s > 1) then
            table.insert(removalList, enemy_context_holder);
            goto continue;
        end

        table.insert(displayList, boss);
		
		::continue::
	end

    table.sort(displayList, function(left, right)
		if left.health_percentage > right.health_percentage then
            return false;
		elseif left.health_percentage < right.health_percentage then
			return true;
		elseif left.name > right.name then
			return false;
		elseif left.name < right.name then
			return true;
		elseif left.health > right.health then
			return true;
		elseif left.health < right.health then
			return false;
		else
			return false;
		end
	end);

    for lua_index, boss in ipairs(displayList) do
        local index = lua_index - 1;
		
        local position = {
            x = anchored_ui_position.x + (spacing.x * index),
            y = anchored_ui_position.y + (spacing.y * index),
        };

        draw_bar(bar, position, boss.health_percentage);
        draw_label(name_label, position, boss.name);
        draw_label(value_label, position, string.format("%.0f/%.0f", boss.health, boss.max_health));
        draw_label(percentage_label, position, string.format("%.1f", 100 * boss.health_percentage));

        index = index + 1;
    end

    for _, enemy_context_holder in ipairs(removalList) do
        bosses[enemy_context_holder] = nil;
    end
end

local function on_draw_ui()

    if imgui.button(string.format("%s##HEALTH_BARS", versioned_mod_name)) then
		is_imgui_window_opened = not is_imgui_window_opened;
	end

    imgui.same_line();

    local changed, new_is_enabled = imgui.checkbox("Enabled##HEALTH_BARS", is_enabled);

	if(changed) then
		is_enabled = new_is_enabled;
	end
end

re.on_frame(function()
    local success, error = pcall(on_frame);
	if not success then
		log.debug(error);
	end
end);

re.on_draw_ui(function()
	local success, error = pcall(on_draw_ui);
	if not success then
		log.debug(error);
	end
end);

pcall(scale_ui);