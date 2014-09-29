-- „Parameter“/„Settings“

-- Wahrscheinlichkeit für jeden Chunk, solche Gänge mit Schienen zu bekommen
-- Probability for every newly generated chunk to get corridors
local probability_railcaves_in_chunk = 0.3

-- Wahrsch. für jeden geraden Teil eines Korridors, Holzkonstruktionen ohne Fackeln zu bekommen
-- Probability for every horizontal part of a corridor to be without light
local probability_torches_in_segment = 0.5

-- Wahrsch. für jeden Teil eines Korridors, nach oben oder nach unten zu gehen
-- Probability for every part of a corridor to go up or down
local probability_up_or_down = 0.27

-- Parameter Ende


-- Zufallsgenerator / random generator
local pr
local pr_initialized = false

function InitRandomizer(seeed)
	pr = PseudoRandom(seeed)
	pr_initialized = true
end
function nextrandom(min, max)
	return pr:next() / 32767 * (max - min) + min
end

-- Würfel…
-- Cube…
function Cube(p, radius, node)
	for zi = p.z-radius, p.z+radius do
		for yi = p.y-radius, p.y+radius do
			for xi = p.x-radius, p.x+radius do
				minetest.set_node({x=xi,y=yi,z=zi}, node)
			end
		end
	end
end

-- Gänge mit Schienen
-- Corridors with rails

function corridor_part(start_point, segment_vector, segment_count)
	local node
	local p = {x=start_point.x, y=start_point.y, z=start_point.z}
	local torches = nextrandom(0, 1) < probability_torches_in_segment
	for segmentindex = 0, segment_count-1 do
		Cube(p, 1, {name="air"})
		-- Diese komischen Holz-Konstruktionen
		-- These strange wood structs
		if segmentindex % 2 == 1 and segment_vector.y == 0 then
			local dir = {0, 0}
			local node_wood = {name="default:wood"}
			local node_fence = {name="default:fence_wood"}
			if segment_vector.x == 0 and segment_vector.z ~= 0 then
				dir = {1, 0}
				torchdir = {5, 4}
			elseif segment_vector.x ~= 0 and segment_vector.z == 0 then
				dir = {0, 1}
				torchdir = {3, 2}
			end
			
			local calc = {
				p.x+dir[1], p.z+dir[2], -- X and Z, added by direction
				p.x-dir[1], p.z-dir[2], -- subtracted
				p.x+dir[2], p.z+dir[1], -- orthogonal
				p.x-dir[2], p.z-dir[1], -- orthogonal, the other way
			}
			minetest.set_node({x=p.x, y=p.y+1, z=p.z}, node_wood)
			minetest.set_node({x=calc[1], y=p.y+1, z=calc[2]}, node_wood)
			minetest.set_node({x=calc[1], y=p.y  , z=calc[2]}, node_fence)
			minetest.set_node({x=calc[1], y=p.y-1, z=calc[2]}, node_fence)
			
			minetest.set_node({x=calc[3], y=p.y+1, z=calc[4]}, node_wood)
			minetest.set_node({x=calc[3], y=p.y  , z=calc[4]}, node_fence)
			minetest.set_node({x=calc[3], y=p.y-1, z=calc[4]}, node_fence)
			 
			if minetest.get_node({x=p.x,y=p.y-2,z=p.z}).name=="air" then
				minetest.set_node({x=calc[1], y=p.y-2, z=calc[2]}, node_fence)
				minetest.set_node({x=calc[3], y=p.y-2, z=calc[4]}, node_fence)
			end
			if torches then
				minetest.set_node({x=calc[5], y=p.y+1, z=calc[6]}, {name="default:torch", param2=torchdir[1]})
				minetest.set_node({x=calc[7], y=p.y+1, z=calc[8]}, {name="default:torch", param2=torchdir[2]})
			end
		end
		
		-- nächster Punkt durch vektoraddition
		-- next way point
		p = vector.add(p, segment_vector)
	end
	p = vector.subtract(p, segment_vector)
end

function corridor_func(waypoint, coord, sign, up_or_down, up)
	local segamount = 3
	if up_or_down then
		segamount = 1
	end
	if sign then
		segamount = 0-segamount
	end
	local vek = {x=0,y=0,z=0};
	if coord == "x" then
		vek.x=segamount
	elseif coord == "z" then
		vek.z=segamount
	end
	if up_or_down then
		if up then
			vek.y = 1
		else
			vek.y = -1
		end
	end
	local segcount = pr:next(4,6)
	corridor_part(waypoint, vek, segcount)
	local corridor_vek = {x=vek.x*segcount, y=vek.y*segcount, z=vek.z*segcount}

	-- nachträglich Schienen legen
	-- after this: rails
	segamount = 1
	if sign then
		segamount = 0-segamount
	end
	if coord == "x" then
		vek.x=segamount
	elseif coord == "z" then
		vek.z=segamount
	end
	if up_or_down then
		if up then
			vek.y = 1
		else
			vek.y = -1
		end
	end
	if not up_or_down then
		segcount = segcount * 2.5
	end
	local minuend = 1
	if up_or_down then
		minuend = minuend - 1
		if not up then
			minuend = minuend - 1
		end
	end
	-- Eigentliches Setzen der Schienen
	-- Actual rails
	for i=1,segcount do
		p = {x=waypoint.x+vek.x*i, y=waypoint.y+vek.y*i-1, z=waypoint.z+vek.z*i}
		if minetest.get_node({x=p.x,y=p.y-1,z=p.z}).name=="air" then
			p.y = p.y - 1;
		end
		minetest.set_node(p, {name = "default:rail"})
	end
	return {x=waypoint.x+corridor_vek.x, y=waypoint.y+corridor_vek.y, z=waypoint.z+corridor_vek.z}
end

function start_corridor(waypoint, coord, sign, psra)
	local wp = waypoint
	local c = coord
	local s = sign
	local ud
	local up	
	for i=1,nextrandom(2,10) do
		-- Nach oben oder nach unten?
		if nextrandom(0, 1) < probability_up_or_down then
			ud = true
			up = nextrandom(0, 2) < 1
		else
			 ud = false
		end
		wp = corridor_func(wp,c,s, ud, up)
		-- coord und sign verändern
		-- randomly change sign and coord
		if c=="x" then
			c="z"
		elseif c=="z" then
			c="x"
	 	end;
		-- Verzweigung?
		-- Fork?
		s = nextrandom(0, 2) < 1
		if nextrandom(0, 15) < nextrandom(0, 1.5) then
			start_corridor(wp, c, not s, psra)
		end
	end
end

function place_corridors(main_cave_coords, psra)
	Cube(main_cave_coords, 4, {name="default:dirt"})
	Cube(main_cave_coords, 3, {name="air"})
	main_cave_coords.y =main_cave_coords.y - 1
	local xs = nextrandom(0, 2) < 1
	local zs = nextrandom(0, 2) < 1;
	start_corridor(main_cave_coords, "x", xs, psra)
	start_corridor(main_cave_coords, "z", zs, psra)
	-- Auch mal die andere Richtung?
	-- Try the other direction?
	if nextrandom(0, 2) < 1 then
		start_corridor(main_cave_coords, "x", not xs, psra)
	end
	if nextrandom(0, 2) < 1 then
		start_corridor(main_cave_coords, "z", not zs, psra)
	end
end

minetest.register_on_generated(function(minp, maxp, seed)	
	if not pr_initialized then
		InitRandomizer(seed)
	end
	if maxp.y < 0 and nextrandom(0, 1) < probability_railcaves_in_chunk then
		-- Mittelpunkt berechnen
		-- Mid point of the chunk
		local p = {x=minp.x+(maxp.x-minp.x)/2, y=minp.y+(maxp.y-minp.y)/2, z=minp.z+(maxp.z-minp.z)/2}
		-- Haupthöhle und alle weiteren
		-- Corridors; starting with main cave out of dirt
		place_corridors(p, pr)
	end
end)
