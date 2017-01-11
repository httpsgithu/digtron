local controller_nodebox ={
	{-0.3125, -0.3125, -0.3125, 0.3125, 0.3125, 0.3125}, -- Core
	{-0.1875, 0.3125, -0.1875, 0.1875, 0.5, 0.1875}, -- +y_connector
	{-0.1875, -0.5, -0.1875, 0.1875, -0.3125, 0.1875}, -- -y_Connector
	{0.3125, -0.1875, -0.1875, 0.5, 0.1875, 0.1875}, -- +x_connector
	{-0.5, -0.1875, -0.1875, -0.3125, 0.1875, 0.1875}, -- -x_connector
	{-0.1875, -0.1875, 0.3125, 0.1875, 0.1875, 0.5}, -- +z_connector
	{-0.5, 0.125, -0.5, -0.125, 0.5, -0.3125}, -- back_connector_3
	{0.125, 0.125, -0.5, 0.5, 0.5, -0.3125}, -- back_connector_1
	{0.125, -0.5, -0.5, 0.5, -0.125, -0.3125}, -- back_connector_2
	{-0.5, -0.5, -0.5, -0.125, -0.125, -0.3125}, -- back_connector_4
}

-- Master controller. Most complicated part of the whole system. Determines which direction a digtron moves and triggers all of its component parts.
minetest.register_node("digtron:controller", {
	description = "Digtron Control Unit",
	groups = {cracky = 3, oddly_breakable_by_hand = 3, digtron = 1},
	drop = "digtron:controller",
	sounds = digtron.metal_sounds,
	paramtype = "light",
	paramtype2= "facedir",
	is_ground_content = false,
	-- Aims in the +Z direction by default
	tiles = {
		"digtron_plate.png^[transformR90",
		"digtron_plate.png^[transformR270",
		"digtron_plate.png",
		"digtron_plate.png^[transformR180",
		"digtron_plate.png",
		"digtron_plate.png^digtron_control.png",
	},
	
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = controller_nodebox,
	},
	
	on_construct = function(pos)
        local meta = minetest.get_meta(pos)
		meta:set_float("fuel_burning", 0.0)
		meta:set_string("infotext", "Heat remaining in controller furnace: 0")
	end,
	
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos)
		if meta:get_string("waiting") == "true" then
			-- Been too soon since last time the digtron did a cycle.
			return
		end
	
		local newpos, status, return_code = digtron.execute_dig_cycle(pos, clicker)
		
		meta = minetest.get_meta(newpos)
		if status ~= nil then
			meta:set_string("infotext", status)
		end
		
		-- Start the delay before digtron can run again.
		minetest.get_meta(newpos):set_string("waiting", "true")
		minetest.get_node_timer(newpos):start(digtron.cycle_time)
	end,
	
	on_timer = function(pos, elapsed)
		minetest.get_meta(pos):set_string("waiting", nil)
	end,
})

-- Auto-controller
---------------------------------------------------------------------------------------------------------------

local auto_formspec = "size[4.5,1]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"field[0.5,0.8;1,0.1;offset;Cycles;${offset}]" ..
	"tooltip[offset;When triggered, this controller will try to run for the given number of cycles. The cycle count will decrement as it runs, so if it gets halted by a problem you can fix the problem and restart.]" ..
	"field[1.5,0.8;1,0.1;period;Period;${period}]" ..
	"tooltip[period;Number of seconds to wait between each cycle]" ..
	"button_exit[2.2,0.5;1,0.1;set;Set]" ..
	"tooltip[set;Saves the cycle setting without starting the controller running]" ..
	"button_exit[3.2,0.5;1,0.1;execute;Set &\nExecute]" ..
	"tooltip[execute;Begins executing the given number of cycles]"

-- Needed to make this global so that it could recurse into minetest.after
digtron.auto_cycle = function(pos)
	local meta = minetest.get_meta(pos)
	local player = minetest.get_player_by_name(meta:get_string("triggering_player"))
	if player == nil or meta:get_string("waiting") == "true" then
		return
	end
	
	local newpos, status, return_code = digtron.execute_dig_cycle(pos, player)
	
	local cycle = 0
	if vector.equals(pos, newpos) then
		cycle = meta:get_int("offset")
		status = status .. string.format("\nCycles remaining: %d\nHalted!", cycle)
		meta:set_string("infotext", status)
		if return_code == 1 then --return code 1 happens when there's unloaded nodes adjacent, just keep trying.
			minetest.after(meta:get_int("period"), digtron.auto_cycle, newpos)
		else
			meta:set_string("formspec", auto_formspec)
		end
		return
	end
	
	meta = minetest.get_meta(newpos)
	cycle = meta:get_int("offset") - 1
	meta:set_int("offset", cycle)
	status = status .. string.format("\nCycles remaining: %d", cycle)
	meta:set_string("infotext", status)
	
	if cycle > 0 then
		minetest.after(meta:get_int("period"), digtron.auto_cycle, newpos)
	else
		meta:set_string("formspec", auto_formspec)
	end
end

minetest.register_node("digtron:auto_controller", {
	description = "Digtron Automatic Control Unit",
	groups = {cracky = 3, oddly_breakable_by_hand = 3, digtron = 1},
	drop = "digtron:auto_controller",
	sounds = digtron.metal_sounds,
	paramtype = "light",
	paramtype2= "facedir",
	is_ground_content = false,
	-- Aims in the +Z direction by default
	tiles = {
		"digtron_plate.png^[transformR90^digtron_auto_control_tint.png",
		"digtron_plate.png^[transformR270^digtron_auto_control_tint.png",
		"digtron_plate.png^digtron_auto_control_tint.png",
		"digtron_plate.png^[transformR180^digtron_auto_control_tint.png",
		"digtron_plate.png^digtron_auto_control_tint.png",
		"digtron_plate.png^digtron_control.png^digtron_auto_control_tint.png",
	},
	
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = controller_nodebox,
	},
	
	on_construct = function(pos)
        local meta = minetest.get_meta(pos)
		meta:set_float("fuel_burning", 0.0)
		meta:set_string("infotext", "Heat remaining in controller furnace: 0")
		meta:set_string("formspec", auto_formspec)
		-- Reusing offset and period to keep the digtron node-moving code simple, and the names still fit well
		meta:set_int("period", digtron.cycle_time)
		meta:set_int("offset", 0)
	end,

	on_receive_fields = function(pos, formname, fields, sender)
        local meta = minetest.get_meta(pos)
		local offset = tonumber(fields.offset)
		local period = tonumber(fields.period)
		
		if period and period > 0 then
			meta:set_int("period", math.max(digtron.cycle_time, math.floor(period)))
		end
		
		if offset and offset >= 0 then
			meta:set_int("offset", math.floor(offset))
			if sender:is_player() and offset > 0 then
				meta:set_string("triggering_player", sender:get_player_name())
				if fields.execute then
					meta:set_string("waiting", nil)
					meta:set_string("formspec", nil)
					digtron.auto_cycle(pos)			
				end
			end
		end
	end,	
	
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", meta:get_string("infotext") .. "\nInterrupted!")
		meta:set_string("waiting", "true")
		meta:set_string("formspec", auto_formspec)
	end,
	
	on_timer = function(pos, elapsed)
		minetest.get_meta(pos):set_string("waiting", nil)
	end,

})

---------------------------------------------------------------------------------------------------------------

-- A much simplified control unit that only moves the digtron, and doesn't trigger the diggers or builders.
-- Handy for shoving a digtron to the side if it's been built a bit off.
minetest.register_node("digtron:pusher", {
	description = "Digtron Pusher Unit",
	groups = {cracky = 3, oddly_breakable_by_hand=3, digtron = 1},
	drop = "digtron:pusher",
	sounds = digtron.metal_sounds,
	paramtype = "light",
	paramtype2= "facedir",
	is_ground_content = false,
	-- Aims in the +Z direction by default
	tiles = {
		"digtron_plate.png^[transformR90^digtron_pusher_tint.png",
		"digtron_plate.png^[transformR270^digtron_pusher_tint.png",
		"digtron_plate.png^digtron_pusher_tint.png",
		"digtron_plate.png^[transformR180^digtron_pusher_tint.png",
		"digtron_plate.png^digtron_pusher_tint.png",
		"digtron_plate.png^digtron_control.png^digtron_pusher_tint.png",
	},
	
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = controller_nodebox,
	},
	
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)	
		local meta = minetest.get_meta(pos)
		if meta:get_string("waiting") == "true" then
			-- Been too soon since last time the digtron did a cycle.
			return
		end

		local newpos, status_text, return_code = digtron.execute_move_cycle(pos, clicker)
		meta = minetest.get_meta(newpos)
		meta:set_string("infotext", status_text)
		
		-- Start the delay before digtron can run again.
		minetest.get_meta(newpos):set_string("waiting", "true")
		minetest.get_node_timer(newpos):start(digtron.cycle_time)
	end,
	
	on_timer = function(pos, elapsed)
		minetest.get_meta(pos):set_string("waiting", nil)
	end,

})