;; ************************************************************************** ;;
;;                                                                            ;;
;;                                                        :::      ::::::::   ;;
;;   gps.lua                                            :+:      :+:    :+:   ;;
;;                                                    +:+ +:+         +:+     ;;
;;   By: ppaglier <ppaglier@student.42.fr>          +#+  +:+       +#+        ;;
;;                                                +#+#+#+#+#+   +#+           ;;
;;   Created: 2020/07/23 02:08:03 by ppaglier          #+#    #+#             ;;
;;   Updated: 2020/07/23 02:08:12 by ppaglier         ###   ########.fr       ;;
;;                                                                            ;;
;; ************************************************************************** ;;

CHANNEL_GPS = 65534
CHANNEL_BROADCAST = 65535

local modem, weather, chatbox
local lampSide = "bottom"
local ComputerName = "Satellite"

local x,y,z
local weatherVal = {rain = false, snow = false}
local GPSServed = 0
local WeatherServed = 0
local count = 0
local lastQuarter = 0


local function TiltLamp()
	for i=1,5,1 do
		rs.setOutput(lampSide, true)
		os.sleep(0.0050)
		rs.setOutput(lampSide, false)
		os.sleep(0.0050)
	end
end

local function open()
	for index, name in pairs(peripheral.getNames()) do
		if (peripheral.getType(name) == "modem" and peripheral.call(name, "isWireless")) then
			print( "Opening modem" )
			modem = peripheral.wrap(name)
			modem.open(CHANNEL_GPS)
			rednet.open(name)
			if (modem.isOpen(CHANNEL_GPS) and rednet.isOpen(name)) then
				weather = peripheral.find("environmentScanner")
				chatbox = peripheral.find("chatBox")
				if (weather == nil) then
					print("Can't find Environment Scanner")
				else
					print("Connect to Environment Scanner")
				end
				if (chatbox== nil) then
					print("Can't find chatBox")
				else
					print("Connect to chatBox")
				end
				return true
			end
			print( "Error: Can't open GPS port." )
			return false
		end
	end
	print("No Wireless Modem attached")
	return false
end

local function WeatherChat()
	if (weather.isRaining() and weatherVal.rain == false) then
		weatherVal.rain = weather.isRaining()
		chatbox.say("It's raining men, HALLELUJAH", -1, true, ComputerName)
	end
	if (weather.isSnow() and weatherVal.snow == false) then
		weatherVal.snow = weather.isSnow()
		chatbox.say("Winter is coming", -1, true, ComputerName)
	end
	if ((weather.isSnow() == false and weatherVal.snow == true) or (weather.isRaining() == false and weatherVal.rain == true)) then
		weatherVal.rain = weather.isRaining()
		weatherVal.snow = weather.isSnow()
		chatbox.say("Praise the sun!", -1, true, ComputerName)
	end
end

local function mainLoop()
	while true do
		local event, p1, p2, p3, p4, p5 = os.pullEvent()
		if event == "modem_message" then
			local modemSide, senderPort, sender, message, senderDistance = p1, p2, p3, p4, p5
			if (message == "PING" and senderPort == CHANNEL_GPS) then
				TiltLamp()
				modem.transmit( sender, CHANNEL_GPS, {x,y,z})
				GPSServed = GPSServed + 1
				if GPSServed > 1 then
					local x,y = term.getCursorPos()
					term.setCursorPos(1,y-2)
				end
				print("GPS: "..GPSServed.." Requests served")
				print("Weather : "..WeatherServed .." Requests served")
			elseif message == "WEATHER" then
				TiltLamp()
				if  (weather ~= nil) then
					modem.transmit(sender, CHANNEL_GPS, {rain = weather.isRaining(), snow = weather.isSnow()})
					WeatherServed = WeatherServed + 1
					if WeatherServed > 1 then
						local x,y = term.getCursorPos()
						term.setCursorPos(1,y-2)
					end
					print("GPS: "..GPSServed.." Requests served")
					print("Weather : "..WeatherServed .." Requests served")
				else
					modem.transmit(sender, CHANNEL_GPS, {rain = false, snow = false})
					print("GPS: "..GPSServed.." Requests served")
					print("Weather: An error has occurred")
				end
			elseif senderPort == CHANNEL_BROADCAST then
				if ((message.sProtocol == "REBOOT" or message.sProtocol == "RESTART") and message.message == "SAT" ) then
					TiltLamp()
					if (senderDistance < 50) then
						os.reboot()
					else
						modem.transmit(sender, os.getComputerID(), "Too much distance for Reboot!")
					end
				end
			end
		elseif event == "command" then
			local sender, args = p1, p2
			if (#args > 0) then
				if (chatbox ~= nil) then
					if args[1] == "time" then
						TiltLamp()
						if (#args > 1 and args[2] == "all") then
							chatbox.say(textutils.formatTime(os.time(), true), 999999, true, ComputerName)
						else
							chatbox.tell(sender, textutils.formatTime(os.time(), true), 999999, true, ComputerName)
						end
					elseif args[1] == "say" then
						TiltLamp()
						local str = ""
						for i=2,#args,1 do
							str = str.. " " ..args[i]
						end
						chatbox.say(str, 999999, true, ComputerName)
					elseif args[1] == "date" then
						TiltLamp()
						if (#args > 1 and args[2] == "all") then
							chatbox.say(tostring(os.day()), 999999, true, ComputerName)
						else
							chatbox.tell(sender, tostring(os.day()), 999999, true, ComputerName)
						end
					elseif #args > 1 and (args[1] == "reboot" or args[1] == "restart") and args[2] == "sat" then
						TiltLamp()
						os.reboot()
					end
				end
			end
		end
		count = count+1
		if (count >= 20) then
			if  (weather ~= nil) then
				if (chatbox ~= nil) then
					WeatherChat()
				end
				TiltLamp()
				rednet.broadcast({rain = weather.isRaining(), snow = weather.isSnow()}, "WEATHER")
				count = 0
			end
		end
		if (chatbox ~= nil and (math.floor(os.time()) % 4) == 0 and lastQuarter ~= math.floor(os.time())) then
			TiltLamp()
			lastQuarter = math.floor(os.time())
			chatbox.say("Il est "..textutils.formatTime(os.time(), true).." !", 999999, true, ComputerName)
		end
		os.sleep(0.05)
	end
end


local function printUsage()
	print( "Usages:" )
	print( "gps host" )
	print( "gps host <x> <y> <z>" )
	print( "gps locate" )
end

local tArgs = { ... }
if #tArgs < 1 then
	printUsage()
	return
end

if tArgs[1] == "locate" then
	if open() then
		gps.locate( 2, true )
	end
elseif tArgs[1] == "host" then
	if turtle then
		print( "Turtles cannot act as GPS hosts." )
		return
	end
	if open() then
		if #tArgs >= 4 then
			x = tonumber(tArgs[2])
			y = tonumber(tArgs[3])
			z = tonumber(tArgs[4])
			if x == nil or y == nil or z == nil then
				printUsage()
				return
			end
			print( "Position is "..x..","..y..","..z )
		else
			x,y,z = gps.locate( 2, true )
			if x == nil then
				print( "Run \"gps host <x> <y> <z>\" to set position manually" )
				return
			end
		end
		print("Serving GPS requests")
		TiltLamp()
		mainLoop()
	end
else
	printUsage()
	return
end