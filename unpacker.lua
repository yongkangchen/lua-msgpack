local m = {}

local function uint8(s)
	return s(1)
end

local function uint16(s)
	local b1, b2 = s(2)
	return b1 * 0x100 + b2
end

local function array(s, n)
	local t = {}
	for i = 1, n do
		t[i] = m.read(s)
	end
	return t
end

local function map(s, n)
	local t = {}
	for _ = 1, n  do
		t[m.read(s)] = m.read(s)
	end
	return t
	-- error("unsupport map")
end

local types_map = {
	[ 0xC0 ] = function() --nil,
		return nil
	end,
	[ 0xC2 ] = function() --false,
		return false
	end,
	[ 0xC3 ] = function() --true,
		return true
	end,
	[ 0xCC ] = uint8,
	[ 0xCD ] = uint16,
	[ 0xCE ] = function(s) --uint32
		local b1, b2, b3, b4 = s(4)
		return ((b1 * 0x100 + b2) * 0x100 + b3) * 0x100 + b4
	end,
	[ 0xCF ] = function(s) --uint64,
		local b1, b2, b3, b4, b5, b6, b7, b8 = s(8)
		return ((((((b1 * 0x100 + b2) * 0x100 + b3) * 0x100 + b4)
			* 0x100 + b5) * 0x100 + b6) * 0x100 + b7) * 0x100 + b8
	end,
	[ 0xD0 ] = function(s) --int8,
		local b1 = s(1)
		if b1 < 0x80 then
	        return b1
	    else
	        return b1 - 0x100
	    end
	end,
	[ 0xD1 ] = function(s) --int16,
		local b1, b2 = s(2)
		if b1 < 0x80 then
	        return b1 * 0x100 + b2
	    else
	        return ((b1 - 0xFF) * 0x100 + (b2 - 0xFF)) - 1
	    end
	end,
	[ 0xD2 ] = function(s) --int32,
		local b1, b2, b3, b4 = s(4)
	    if b1 < 0x80 then
	        return ((b1 * 0x100 + b2) * 0x100 + b3) * 0x100 + b4
	    else
	        return ((((b1 - 0xFF) * 0x100 + (b2 - 0xFF)) * 0x100
	        	+ (b3 - 0xFF)) * 0x100 + (b4 - 0xFF)) - 1
	    end
	end,
	[ 0xD3 ] = function(s) --int64,
		local b1, b2, b3, b4, b5, b6, b7, b8 = s(8)
	    if b1 < 0x80 then
	        return ((((((b1 * 0x100 + b2) * 0x100 + b3) * 0x100 + b4)
	        	 * 0x100 + b5) * 0x100 + b6) * 0x100 + b7) * 0x100 + b8
	    else
	        return ((((((((b1 - 0xFF) * 0x100 + (b2 - 0xFF)) * 0x100
	        	+ (b3 - 0xFF)) * 0x100 + (b4 - 0xFF)) * 0x100 + (b5 - 0xFF))
	        	* 0x100 + (b6 - 0xFF)) * 0x100 + (b7 - 0xFF)) * 0x100
	        	+ (b8 - 0xFF)) - 1
	    end
	end,
	[ 0xD7 ] = function(s) --map8
		return map(s, uint8(s))
	end,
	[ 0xD8 ] = function(s) --array8
		return array(s, uint8(s))
	end,
	[ 0xD9 ] = function(s) --str8,
		return s(uint8(s), true)
	end,
	[ 0xDA ] = function(s) --str16,
		return s(uint16(s), true)
	end,
	[ 0xDC ] = function(s) --array16
		return array(s, uint16(s))
	end,
	[ 0xDE ] = function(s) --map16
		return map(s, uint16(s))
	end,
}

local function positivefixint(_, t)
	return t
end

local function fixarray(s, t)
	return array(s, t % 0x10)
end

local function fixstr(s, t)
	return s(t % 0x20, true)
end

local function negativefixint(_, t)
	return t - 0x100
end

local fixmap = function(s, t)
	return map(s, t % 0x10 )
end

local function get_parse_func( t )
	local v = types_map[t]
	if v ~= nil then
		return v
	end

	if t < 0xC0 then
		if t <= 0x80 then
			return positivefixint
		elseif t < 0x90 then
			return fixmap
		elseif t < 0xA0 then
			return fixarray
		else
			return fixstr
		end
	elseif t > 0xDF then
		return negativefixint
	else
		return
	end
end

function m.read(reader)
	local t = reader(1)
	local f = get_parse_func(t)
	if f == nil then
		error("unsupport t: " .. tostring(t))
	end
	return f(reader, t)
end

return m
