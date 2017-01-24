local native_modbus = {}

--- debug function ---
function debug ( level, ... )
  if ( debug_level and level <= debug_level ) then
    print ( "DEBUG: " .. ... )
  end
end

if package.loaded["bit32"] then
  debug ( 1, "Module bit32 exists" )
  bit32 = require( "bit32" )
elseif package.loaded["bit"] then
  debug ( 1, "Module bit exists" )
  bit32 = require( "bit" )
else
  debug ( 1, "No bit modules exists" )
  return nil
end


socket = require( "socket" )


local RTU, ASCII, TCP, RTUoTCP, ASCIIoTCP = 0, 1, 2, 4, 8
local ERROR, WARNING, INFO = 2, 1, 0

-- native_modbus.__index = native_modbus
--- variable ---
native_modbus.type = RTU
native_modbus.host = nil
native_modbus.port = nil
native_modbus.type = ASCIIoTCP
native_modbus.buffer_size = 256
native_modbus.buffer = ""
native_modbus.session = 0
native_modbus.device = nil
native_modbus.frame = nil
native_modbus.lrc = nil
native_modbus.read_delay = 0


modbus_frame = {}
modbus_frame.slave = nil
modbus_frame.function_code = nil
modbus_frame.size = nil
modbus_frame.address = nil
modbus_frame.raw_value = nil
modbus_frame.values = {}
modbus_frame.exception = 0
modbus_frame.exception_string = "None"


function modbus_frame.new ( slave, function_code )
  _mf =  {}
  setmetatable(_mf, self)
  self.__index = self
  _mf.slave = slave
  _mf.function_code = function_code
  _mf.values = {}
  return _mf
end

function modbus_frame:print()
  debug ( 5, "modbus_frame:print()" )
  --modbus_frame_string = "Frame slave " .. tostring(self.slave) .. " function code " .. tostring(self.function_code) .. " size " .. tostring(self.size) .. " address " .. tostring(self.address) .. " value " .. native_modbus.packetdump(self.raw_value) .. " values " .. #self.raw_value .. " exception " .. tostring(self.exception_string)
  modbus_frame_string = "Frame slave " .. tostring(self.slave) .. " function code " .. tostring(self.function_code) .. " size " .. tostring(self.size) .. " address " .. tostring(self.address) .. " value " .. native_modbus.packetdump(self.raw_value) .. " exception " .. tostring(self.exception_string)
--  elseif ( self.exception ~= 0 ) then
--    modbus_frame_string =  string.format ( "Frame with modbus exception %s (%d)", self.exception_string, self.exception )
--  end

  debug ( 5,  modbus_frame_string )
  return modbus_frame_string
end

function modbus_frame:copy()
  debug ( 5, "modbus_frame:copy()" )
  --modbus_frame_string = "Frame slave " .. tostring(self.slave) .. " function code " .. tostring(self.function_code) .. " size " .. tostring(self.size) .. " address " .. tostring(self.address) .. " value " .. native_modbus.packetdump(self.raw_value) .. " values " .. #self.raw_value .. " exception " .. tostring(self.exception_string)
 
  frame = modbus_frame:new()
  frame.size = self.size
  frame.exception = self.exception
  frame.values  = shallowcopy(self.values)
  modbus_frame_string = "Frame slave " .. tostring(self.slave) .. " function code " .. tostring(self.function_code) .. " size " .. tostring(self.size) .. " address " .. tostring(self.address) .. " value " .. native_modbus.packetdump(self.raw_value) .. " exception " .. tostring(self.exception_string)
  
  debug ( 5, modbus_frame_string )
  return frame
end

function modbus_frame:crop_values( initial, final )
  debug ( 5, string.format ( "modbus_frame:crop_values( %s, %s)", tostring(initial), tostring(final) ) )
  --modbus_frame_string = "Frame slave " .. tostring(self.slave) .. " function code " .. tostring(self.function_code) .. " size " .. tostring(self.size) .. " address " .. tostring(self.address) .. " value " .. native_modbus.packetdump(self.raw_value) .. " values " .. #self.raw_value .. " exception " .. tostring(self.exception_string)
 
  if ( initial == nil ) then
    debug ( 5, "modbus_frame:crop_values(): nil initial, not removing starting values")
  else
    for i=1,initial,1 do 
      table.remove(self.values, 1) 
    end
    self.size = self.size - initial
  end 
  
  
  if ( final == nil ) then
    debug ( 5, "modbus_frame:crop_values(): nil final, not removing ending values")
  else
    for i=final,#self.values,1 do 
      table.remove(self.values, i) 
    end
    self.size = self.size - final
  end 

  return frame
end

function native_modbus.new ( type, param1 )
  _mdn = {}
  if ( type ~= nil ) then
    _mdn.type = type
  end
  setmetatable(_mdn, self)
  self.__index = self
  return _mdn
end

function native_modbus:new ( type, param1 )
  _mdn = {}
  if ( type ~= nil ) then
    debug ( 5, "native_modbus:new(): No type" )
    _mdn.type = type
  end
  setmetatable(_mdn, self)
  self.__index = self
  return _mdn
end

function native_modbus:openDevice()
  debug ( 1, string.format ( "native_modbus:openDevice(): opening device" ) )
  if ( self.type == RTU ) or ( self.type == ASCII ) then
    debug ( 1, string.format ( "Connecting to serial interface %s", tostring(self.device) ) )
  else
    if ( self.host == nil or self.port == nil ) then
        debug ( 5, "native_modbus:openDevice(): Remote host and port not set" )
        return false
      
    end
    
    debug ( 1, string.format ( "Connecting to host %s port %d", self.host, self.port ) )  
    self.device = socket.connect(self.host,self.port)
    debug ( 5, string.format ( "Socket %s", tostring (self.device) ) )
    self.device:settimeout(0.3)
    -- client:setoption("tcp-nodelay",true)
    self.device:setoption("keepalive",true)
    return self.device
  end
  
  return nil
end

function native_modbus:closeDevice()
  debug ( 5, string.format ( "native_modbus:closeDevice(): closing device" ) )
  if ( self.type == RTU ) or ( self.type == ASCII ) then
    debug ( 5, string.format ( "native_modbus:closeDevice(): closing to serial interface %s", tostring(self.device) ) )
  else
    if ( self.device == nil ) then
        debug ( 5, "native_modbus:closeDevice(): socket already closed" )
        return nil
      
    end
    
    debug ( 5, string.format ( "native_modbus:closeDevice(): closing connection to host %s port %d", self.host, self.port ) )  
    ret = self.device:close()
    self.device = nil
    
    return ret
  end
  
  return nil
end

function native_modbus:prepareFrame( slave, command, address, size )
    address_high =  bit32.rshift(address, 8)
    address_low = bit32.band(address, 255)
    
    size_high = bit32.rshift(size, 8)
    size_low = bit32.band(size, 255)
    raw_frame = string.char ( slave, command, address_high, address_low, size_high, size_low )
    -- print ( self.packetdump ( raw_frame ) )
    lrc = native_modbus:calculateLRC(raw_frame)
    if ( self.type == ASCII ) or ( self.type == ASCIIoTCP ) then
      debug (5, "native_modbus:prepareFrame: Creating ASCII request" )
      frame = string.upper( string.format(":%02x%02x%04x%04x%02x\r\n", slave, command, address, size, lrc ) )
      debug ( 5, "native_modbus:prepareFrame: ASCII frame: " .. frame )
      debug ( 5, native_modbus:packetdump(frame) )
    else
      debug (5, "native_modbus:prepareFrame: Creating RTU request. NOT IMPLEMENTED YET" )
    end
 
    mdn_string = "Modbus type " .. tostring(self.type) 
    self.frame = frame
    return frame
end

function native_modbus:parseFrame( frame )
  debug ( 5, string.format ( "native_modbus:parseFrame ( %s )", tostring ( frame ) ) )
    if ( self.type == ASCII ) or ( self.type == ASCIIoTCP ) then
      debug ( 5, "native_modbus:prepareFrame: Parsing ASCII frame" )
      ascii = true
    else
      debug ( 5, "native_modbus:prepareFrame: Parsing RTU frame" )  
      ascii = false
    end
    
    if ( frame == nil ) then
      debug ( 1, "native_modbus:parseFrame() nil frame")
      return nil
    end
    
    if ( ascii == true ) then
      separator = string.sub ( frame, 1, 1 )
      debug ( 5, string.format ( "native_modbus:parseFrame() Separator: %s", separator ) )
      if ( separator ~= ":" ) then
        debug ( 5, "native_modbus:parseFrame() Wrong separator " .. tostring(separator) )
        return nil
      end
      frame_len = string.len( frame )
      slave_address_ascii = string.sub ( frame, 2, 3 )
      slave_address = tonumber ( slave_address_ascii, 16  )
      debug ( 5, string.format ( "Slave: 0x%02x (%s)", slave_address, slave_address_ascii ) )
      fc_ascii = string.sub ( frame, 4, 5 )
      fc = tonumber ( fc_ascii, 16 )
      size_ascii = string.sub ( frame, 6, 7 )
      size = tonumber ( size_ascii, 16 )
      debug ( 5, string.format ( "Function code: %d (%s)", fc, fc_ascii ) )
      lrc_ascii = string.sub ( frame, frame_len-1, frame_len )
      lrc = tonumber ( lrc_ascii, 16 )
      data_ascii = string.sub ( frame, 8, frame_len-2 )
      -- data = tonumber ( size_ascii, 16 )
      
      rtu = ""
      rtu = string.char ( slave_address ) .. string.char(fc) .. string.char(size)
      data = ""
      debug ( 10, "Data length: " .. #data_ascii )
      bytes_per_data = 1
      if ( fc == 3 ) then
        bytes_per_data = 2
      end
      debug ( 5, "Data: " .. data_ascii)
      
      for index=1, #data_ascii, 2 do
        byte = string.sub ( data_ascii, index, index+1)
        debug ( 10, string.format ( "Index: %d, Byte: %s", index, byte ) )
        data = data .. string.char ( tonumber(byte,16) )
        rtu = rtu .. string.char ( tonumber(byte,16) )
      end       
      
--      for index=1, #data_ascii-2*bytes_per_data, 2*bytes_per_data do
--        for byte_index=0, bytes_per_data*2-1, 1 do
--          byte = string.sub ( data_ascii, index+byte_index, index+byte_index+1)
--  --        byte2 = string.sub ( data_ascii, index+2, index+3)
--          debug ( 10, string.format ( "Index: %d (%d), Byte: %s", index+byte_index, byte_index, byte ) )
--          data = data .. string.char ( tonumber(byte,16) )
--          rtu = rtu .. string.char ( tonumber(byte,16) )
--        end       
--      end
      
      debug ( 5, string.format ( "Data: %s (%s)", self.packetdump(data), data_ascii ) )
      debug ( 5, string.format ( "RTU: %s", self.packetdump(rtu) ) )

      debug ( 5, string.format ( "LRC: %x (%s)", lrc, lrc_ascii ) )
      -- print ( "Type: " .. type (slave_address ) .. type(size) .. type (data) )
      
      debug ( 5, self.packetdump ( rtu ) )
      calc_lrc = self:calculateLRC( rtu )
      if ( calc_lrc ~= lrc ) then
        debug ( 5, "Packet received with incorrect LRC" )
        return nil
      end      
    else
    -- TODO: Add support for RTU and TCP      
    end
    
    return self:handleFrame ( rtu )
    
end

function native_modbus:handleFrame( rtu )
  debug ( 5, string.format( "native_modbus:handleFrame ( %s )", native_modbus.packetdump(rtu) ) )
  if ( rtu == nil ) then
      debug ( 5, "native_modbus:handleFrame (): Nil RTU" )
      return nil
  end
  
  local frame = modbus_frame:new()
  frame.slave = string.byte( rtu, 1, 1 )
  frame.function_code = string.byte( rtu, 2, 2 )
  
  if ( frame.function_code == 0x01 ) then
    frame.size = string.byte( rtu, 3, 4 )
  elseif ( frame.function_code == 0x02 ) then
    frame.size = string.byte( rtu, 3 )
    frame.raw_value = ""
    debug ( 5, string.format ( "Reading %d bytes of data", frame.size ) )
    for index = 4, frame.size+3, 1 do
      value = string.sub( rtu, index, index )
      frame.raw_value = frame.raw_value .. value
      table.insert ( frame.values, value )
    end
    debug ( 5, native_modbus.packetdump(frame.raw_value) )
  elseif ( frame.function_code == 0x03 ) then
    frame.size = string.byte( rtu, 3 )
    frame.raw_value = ""
    

    debug ( 5, string.format ( "Reading %d bytes of data", frame.size ) )
    for index = 1, frame.size, 2 do
      value = string.sub( rtu, 3 + index, 3 + index ) .. string.sub( rtu, 3 + index + 1, 3 + index + 1  )
      frame.raw_value = frame.raw_value .. value
      table.insert ( frame.values, value )
      -- print ( "Byte: " .. native_modbus.packetdump(frame.raw_value) )
    end
    debug ( 5, native_modbus.packetdump(frame.raw_value) )
  elseif ( frame.function_code == 0x05 ) then
    frame.address = string.byte( rtu, 3 ) * 256 + string.byte( rtu, 4 )
    frame.raw_value = string.byte( rtu, 5 ) * 256 + string.byte( rtu, 6 )
elseif ( frame.function_code == 0x06 ) then
    frame.size = 1
    frame.address = string.byte( rtu, 3 )*256+string.byte( rtu, 4 )
    frame.raw_value = ""
    
    debug ( 5, string.format ( "Reading %d bytes of data", frame.size ) )
    for index = 1, frame.size, 2 do
      value = string.sub( rtu, 4 + index, 4 + index ) .. string.sub( rtu, 4 + index + 1, 4 + index + 1  )
      frame.raw_value = frame.raw_value .. value
      table.insert ( frame.values, value )
      -- print ( "Byte: " .. native_modbus.packetdump(frame.raw_value) )
    end
    debug ( 5, native_modbus.packetdump(frame.raw_value) )
  elseif ( frame.function_code == 0x83 ) then
    debug ( 5, "Modbus exception" )
    frame.exception = rtu:byte( 3 )
    if ( frame.exception == 1 ) then
      frame.exception_string = "Illegal function"
    elseif ( frame.exception == 2 ) then
      frame.exception_string = "Illegal data address"
    elseif ( frame.exception == 3 ) then
      frame.exception_string = "Illegal data value"
    elseif ( frame.exception == 4 ) then
      frame.exception_string = "Slave device failure"
    elseif ( frame.exception == 5 ) then
      frame.exception_string = "Aknowledge"
    elseif ( frame.exception == 6 ) then
      frame.exception_string = "Slave device busy"
    elseif ( frame.exception == 8 ) then
      frame.exception_string = "Memory parity error"
    elseif ( frame.exception == 0x0a ) then
      frame.exception_string = "Gateway path unavailable"
    elseif ( frame.exception == 0x0b ) then
      frame.exception_string = "Gateway target device failed to respond"
    end
    frame.raw_value = nil
    frame.values = nil
  else
    print ( "Function code not implemented" )
  end
  
  frame:print()
  return frame
  
  
  
end


function native_modbus:sendFrame( frame )
  debug ( 5, string.format( "native_modbus:sendFrame ( %s )", tostring(frame) ) )
  if ( self.device == nil ) then
    debug ( 5, "native_modbus:sendFrame() device is closed" )
    local ret = self:openDevice()
      if ( ret == false or ret == nil ) then
          print ( "Unable to open device" )
          return false
      end
      
  end
  
  if ( self.type == TCP ) or ( self.type == RTUoTCP ) or ( self.type == ASCIIoTCP ) then
    debug ( 5, string.format( "native_modbus:sendFrame () sending over TCP " ) )
    self.device:send(self.frame)
    self.frame = nil
  else
  
  end
end


function native_modbus:calculateLRC ( frame )
  debug ( 5, "native_modbus:calculateLRC()" )
  if ( frame == nil ) and ( self.frame == nil ) then
      print ( "No frame to calculate LRC" )
      return nil
  end
  local temp_lrc = 0
  length = string.len ( frame )
  for i = 1, length, 1 do
    temp_lrc = temp_lrc + string.byte(frame,i)
    debug ( 10, "Adding " .. string.byte(frame,i) .. " to LRC" )
  end
  lrc = ( -temp_lrc ) % 0x100
  debug ( 5, string.format ( "Temp LRC: 0x%02x (%d) LRC:  %02X (%d)", temp_lrc, temp_lrc, lrc, lrc ) )
  return lrc
end

function native_modbus:writeSingleCoil( slave, address, status )
    if ( slave == nil ) then
      slave = 1
    end
    if ( address == nil ) then
      address = 0
    end
    if ( size == nil ) then
      size = 1
    end
    if ( status == true or status == 1 ) then
      status = 0xff00
    end
    
  debug ( 5, string.format ( "native_modbus:writeSingleCoil ( 0x%02x, 0x%04x, 0x%04x )", slave, address, status ) )
  self:prepareFrame ( slave, 5, address, status )
  self:sendFrame()
    -- print ( zone_string )
    -- return mdn_string
end



function native_modbus:readHoldingRegister( slave, address, size )
    if ( slave == nil ) then
      slave = 1
    end
    if ( address == nil ) then
      address = 0
    end
    if ( size == nil ) then
      size = 1
    end
  debug ( 5, string.format ( "native_modbus:readHoldingRegisteer ( 0x%02x, 0x%04x, 0x%04x )", slave, address, size ) )
  self:prepareFrame ( slave, 3, address, size )
  self:sendFrame()
    -- print ( zone_string )
  return self:getFrame()
end

function native_modbus:getFrame ()
  debug ( 5, string.format ( "native_modbus:getFrame()" ) )
	local try = 0
  local packets = {}
  if ( self.device == nil ) then
    print ( "native_modbus:getFrame(): error handling nil device" )
    return
  end
  
  size = 0
  frame = ""
	while ( true ) do
		try = try + 1
		if ( try > 3 ) then
			debug ( 1, "native_modbus:getFrame(): too many tries" )
			return nil
		end
		
		socket.sleep ( self.read_delay )
		incoming, error, partial = self.device:receive ("*a")
		recv_buffer = nil
		if ( incoming and not error ) then
			debug ( 10, "Incoming " .. incoming .. " dump: " ..native_modbus.packetdump ( incoming ) )
			frame = frame .. incoming
		elseif ( error == 'timeout' and partial ) then
			debug ( 10, "Partial string. Dump: " .. native_modbus.packetdump ( partial ) )
			frame = frame .. partial
		else
			debug ( 1, "Error reading from socket: " .. error .. native_modbus.packetdump ( incoming )  .. " partial " ..           native_modbus.packetdump(partial))
      return nil
		end
	
	
  	length = #frame
  	debug ( 10, "native_modbus:getFrame(): frame " .. frame )
    for index = 1, length, 1 do
      if frame:sub(index,index) == ":" then
        size = tonumber ( frame:sub(6,7), 16 )
        debug ( 10, "native_modbus:getFrame(): found separator byte at "..index .. " frame size " .. size )
        if sync_found == 1 then
          frame = frame:sub( index, string.len(frame) )
          debug ( 10, "native_modbus:getFrame(): packet start "..sync_index.." end "..index-1 )
         
          sync_found = 0
        else
          sync_index = index
          sync_found = 1
        end
        debug ( 10, "native_modbus:getFrame(): frame len "..frame:len() .. " size " .. size )
        if ( frame:len() >= size*2 + 11 ) then
          debug ( 10, "native_modbus:getFrame(): reached correct length" )
          frame = string.gsub(frame, "%s+", "")
          return self:parseFrame( frame )
        end
      end
    end  
  end
	
  frame = string.gsub(frame, "%s+", "")
  return self:parseFrame( frame )
end

function native_modbus:readInputStatus( slave, address, size )
    if ( slave == nil ) then
      slave = 1
    end
    if ( address == nil ) then
      address = 0
    end
    if ( size == nil ) then
      size = 1
    end
  debug ( 5, string.format ( "native_modbus:readInputStatus ( 0x%02x, 0x%04x, 0x%04x )", slave, address, size ) )
  self:prepareFrame ( slave, 2, address, size )
  self:sendFrame()
  return self:getFrame()
end

function native_modbus:readInputRegister( slave, address, size )
    if ( slave == nil ) then
      slave = 1
    end
    if ( address == nil ) then
      address = 0
    end
    if ( size == nil ) then
      size = 1
    end
  debug ( 5, string.format ( "native_modbus:readInputRegister ( 0x%02x, 0x%04x, 0x%04x )", slave, address, size ) )
  self:prepareFrame ( slave, 4, address, size )
  self:sendFrame()
    -- print ( zone_string )
    -- return mdn_string
end

function native_modbus:writeSingleRegister( slave, address, data )
    if ( slave == nil ) then
      slave = 1
    end
    if ( address == nil ) then
      address = 0
    end
    if ( data == nil ) then
      print ( "Data missing" )
      return nil
    end
  debug ( 5, string.format ( "native_modbus:writeSingleRegister ( 0x%02x, 0x%04x, 0x%04x )", slave, address, data ) )
  self:prepareFrame ( slave, 6, address, data )
  self:sendFrame()
  local return_frame = self:getFrame()
  debug ( 5, "Retuned frame: " .. return_frame:print() )
  return return_frame
end

function native_modbus:writeSingleCoil( slave, address, status )
    if ( slave == nil ) then
      slave = 1
    end
    if ( address == nil ) then
      address = 0
    end
    if ( status == nil ) then
      print ( "Data missing" )
      return nil
    end
  debug ( 5, string.format ( "native_modbus:writeSingleCoil ( 0x%02x, 0x%04x, %s )", slave, address, tostring(status) ) )
  
  if ( status == true ) then
    data = 0xff00
  elseif ( status == false ) then
    data = 0x0000
  else
    debug ( 1, string.format ( "native_modbus:writeSingleCoil: must be a boolean" ) )
  end
  
  self:prepareFrame ( slave, 5, address, data )
  self:sendFrame()
  local return_frame = self:getFrame()
  debug ( 5, "Retuned frame: " .. return_frame:print() )
  return return_frame
end




function native_modbus:readCoils( slave, address, size )
    if ( slave == nil ) then
      slave = 1
    end
    if ( address == nil ) then
      address = 0
    end
    if ( size == nil ) then
      size = 1
    end
    debug ( 5, string.format ( "native_modbus:readCoils ( 0x%02x, 0x%04x, 0x%04x )", slave, address, size ) )
 
    print ( "Size " .. size )
    self:prepareFrame ( slave, 1, address, size )
    -- print ( zone_string )
    -- return mdn_string
end

function native_modbus:print()
    mdn_string = "Modbus type " .. tostring(self.type) 
    print ( mdn_string )
    return mdn_string
end

function native_modbus.packetdump(packet)
	local length
	local hexdump
  local dump_string = ""
  if ( packet == nil ) then
      dump_string = "native_modbus.packetdump(): nil packet"
      return dump_string
  end
  
  if ( type(packet) == "table" ) then
      debug ( 5, "native_modbus.packetdump(): table packet " .. #packet)
      dump_string = "native_modbus.packetdump(): table packet"
      dump_string = dump_string .. " length " .. #packet .. " "
      -- for index = 1, #packet, 1 do
      for i, v in ipairs(packet) do
--        dump_string = dump_string .. string.format( '0x%02x ', packet[index]:byte( 1 ), packet[index]:byte( 1 ) )
        debug ( 20, "native_modbus.packetdump(): index " .. i .. " value " .. v:byte())
        dump_string = dump_string .. string.format( '0x%02x ', v:byte( 1 ) )  
        
      end
      
      return dump_string
  end
  
	length = string.len ( packet )
	
	debug ( 30, "native_modbus.packetdump(): packet "..packet)
	dump_string = dump_string .. " length " .. length .. " "
  -- print ( "Packet length: "..length.."\n" )
	for i = 1, length, 1 do
		-- print ( "Index "..i)
		-- print ( "Byte "..string.byte(packet,i,i))
		-- io.write(string.format('0x%02X ',string.byte(packet,i)))
    dump_string = dump_string .. string.format('0x%02X ',string.byte(packet,i) )

		-- hexdump = hexdump..string.format("[%d] %02x ", i, string.byte(packet,i) )
		-- hexdump = hexdump..string.format("[%d] 0x%02x ", i, packet:byte(i) )
	end
	-- print ( dump_string )
	return dump_string
	

end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end


return native_modbus
