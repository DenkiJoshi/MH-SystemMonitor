---@diagnostic disable: undefined-global

local update_interval_seconds = 2.0;
local max_monsters_to_track = 3;
local output_file_path = "monster_hp_data.json";
local next_json_write_time = 0;

local function number_is_equal(value1, value2)
	return math.abs(value1 - value2) < 0.000001;
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
local boss_count = 0;
local update_pending = false;
local sorted_bosses = {};

local function init_json_file()
    local file = io.open(output_file_path, "w");
    if file then
        file:write('{"monsters":[]}');
        file:close();
    end
end

local function on_update(enemy_context)
	if enemy_context == nil then
		return;
	end

	local boss = bosses[enemy_context];

	if boss == nil then
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
			name = name,
			health_manager = health_manager,
			health = 0,
			max_health = 0,
			cached_health = 0,
			cached_max_health = 0,
			percent = 100,
			last_update = os.clock(),
			last_valid_hp_time = 0
		};
		
		bosses[enemy_context] = boss;
		boss_count = boss_count + 1;
	end

	local health = get_health_method:call(boss.health_manager);
	local max_health = get_max_health_method:call(boss.health_manager);
	
	local health_valid = (health ~= nil);
	local max_health_valid = (max_health ~= nil);
	local current_time = os.clock();
	
	if health_valid and max_health_valid then
	    boss.cached_health = health;
	    boss.cached_max_health = max_health;
	    boss.last_valid_hp_time = current_time;

		boss.health = health;
		boss.max_health = max_health;
		boss.percent = (health / max_health) * 100;
		boss.last_update = current_time;
		
		update_pending = true;
	else
	    if boss.cached_health > 0 and boss.cached_max_health > 0 then
	        if current_time - boss.last_valid_hp_time < 5.0 then
	            boss.health = boss.cached_health;
    		    boss.max_health = boss.cached_max_health;
    		    boss.last_update = current_time;
    		    
    		    update_pending = true;
    		end
	    end
	end
end

sdk.hook(get_is_angry_method, function(args)
	local enemy_context = sdk.to_managed_object(args[2]);
	pcall(on_update, enemy_context);
end, function(return_value)
	return return_value;
end)

local function update_boss_list()
    if boss_count == 0 then
        return;
    end
    
    local current_time = os.clock();
    
    local to_remove = {};
    for ctx, boss in pairs(bosses) do
        if number_is_equal(boss.health, 0) or (current_time - boss.last_update > 3) then
            to_remove[ctx] = true;
        end
    end
    
    for ctx, _ in pairs(to_remove) do
        bosses[ctx] = nil;
        boss_count = boss_count - 1;
    end
    
    sorted_bosses = {};
    for _, boss in pairs(bosses) do
        table.insert(sorted_bosses, boss);
    end
    
    table.sort(sorted_bosses, function(a, b)
        return a.percent < b.percent;
    end);
end

local function write_json()
    if not update_pending then
        return;
    end
    
    update_boss_list();
    
    if #sorted_bosses == 0 then
        local file = io.open(output_file_path, "w");
        if file then
            file:write('{"monsters":[]}');
            file:close();
        end
        update_pending = false;
        return;
    end
    
    local parts = {};
    parts[1] = '{"monsters":[';
    
    local count = math.min(#sorted_bosses, max_monsters_to_track);
    for i = 1, count do
        local boss = sorted_bosses[i];
        
        parts[i+1] = i > 1 and ',' or '';
        parts[i+1] = parts[i+1] .. '{"name":"' .. boss.name .. 
               '","hp":' .. math.floor(boss.health) .. 
               ',"max_hp":' .. math.floor(boss.max_health) .. 
               ',"hp_percent":' .. math.floor(boss.percent) .. '}';
    end
    
    parts[count+2] = ']}';
    
    local json = table.concat(parts);
    
    local file = io.open(output_file_path, "w");
    if file then
        file:write(json);
        file:close();
    end
    
    update_pending = false;
end

local function check_timer()
    local current_time = os.clock();
    
    if current_time < next_json_write_time then
        return;
    end
    
    next_json_write_time = current_time + update_interval_seconds;
    write_json();
end

init_json_file();

re.on_application_entry("UpdateBehavior", function()
    check_timer();
end);

log.info("Monster HP to JSON (Version 4 - Cached Health) loaded");