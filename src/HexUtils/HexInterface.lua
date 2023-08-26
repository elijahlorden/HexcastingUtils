local HexInterface = {}
HexInterface.iotas = {}

-- Base Hex Casting Iotas --

HexInterface.iotas.null = function() return { null = true } end
HexInterface.iotas.garbage = function() return { garbage = true } end
HexInterface.iotas.vector = function(x, y, z) return { x = x, y = y, z = z } end
HexInterface.iotas.entity = function(uuid) return { uuid = uuid } end
HexInterface.iotas.pattern = function(direction, angles) return { startDir = direction, angles = angles } end

-- List: indexed table with non-nil values
-- Boolean: bool
-- Number: number

-- Hexal Iotas --

-- More Iotas Iotas --





local xiMethods = {
	read = function(self) return self._peripheral.readIota() end,
	canRead = function(self) return self._peripheral.hasFocus() end,
	readType = function(self) return self._peripheral.getIotaType() end,
	write = function(self, iota) return self._peripheral.writeIota(iota) end,
	canWrite = function(self, iota) return self:canRead() and self._peripheral.canWriteIota(iota or 0) end,
	slots = function(self) return self._peripheral.getSlotCount() end,
	slot = function(self, slot) return slot and self._peripheral.setCurrentSlot(slot) or self._peripheral.getCurrentSlot() end
}

local xiMeta = { __index = xiMethods }

HexInterface.new = function(p)
	local p = p or peripheral.find("focal_port")
	assert(p, "Nil focal port")
	xi = setmetatable({ _peripheral = p }, xiMeta)
	return xi
end


return HexInterface