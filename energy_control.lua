;; ************************************************************************** ;;
;;                                                                            ;;
;;                                                        :::      ::::::::   ;;
;;   energy_control.lua                                 :+:      :+:    :+:   ;;
;;                                                    +:+ +:+         +:+     ;;
;;   By: ppaglier <ppaglier@student.42.fr>          +#+  +:+       +#+        ;;
;;                                                +#+#+#+#+#+   +#+           ;;
;;   Created: 2020/07/23 02:10:47 by ppaglier          #+#    #+#             ;;
;;   Updated: 2020/07/23 02:10:50 by ppaglier         ###   ########.fr       ;;
;;                                                                            ;;
;; ************************************************************************** ;;

local batteries = {}
local rednetInfo = {"EnergyControl", "MainBase"}
local BatterieTypes = {"ic2:oldbatbox","ic2:oldmfe","ic2:oldmfsu"};
local AutoDetect = true

if (fs.exists("EnergyConfig") and os.loadAPI("EnergyConfig")) then
	if (EnergyConfig.rednetInfo ~= nil) then
		rednetInfo = EnergyConfig.rednetInfo
	end
	if (EnergyConfig.BatterieTypes ~= nil) then
		BatterieTypes = EnergyConfig.BatterieTypes
	end
	print("Custom Config : Load!")
	os.sleep(1)
end

term.clear()
term.setCursorPos(1,1)

local function getNbBatteries()
	local size = 0
	for index, batterie in pairs(batteries) do
		if (peripheral.isPresent(index)) then
			size = size + 1
		else
			batteries[index] = nil
		end
	end
	return size
end

local function findBatteries()
	for _,name in pairs(peripheral.getNames()) do
		for index, type in pairs(BatterieTypes) do
			if (peripheral.getType(name) == type and batteries[name] == nil) then
				batteries[name] = peripheral.wrap(name)
			end
		end
	end
	getNbBatteries()
end

local function getBatterieInfo(index)
if (batteries[index] == nil) then
	return 0, 0
end
local ok, stored = pcall(batteries[index].getEUStored)
	if(ok == false or stored == nil) then
		stored = 0
	end
local ok, capacity = pcall(batteries[index].getEUCapacity)
	if(ok == false or capacity == nil) then
		capacity = 0
	end
	return stored , capacity
end

local function getWirelessModemSide()
	local lstSides = {"left","right","top","bottom","front","back"};
	
	for index, side in pairs(lstSides) do
		if (peripheral.isPresent(side)) then
			if (peripheral.getType(side) == string.lower("modem")) then
				if (peripheral.call(side, "isWireless")) then
					return side;
				end
			end
		end
	end
	return nil;
end

findBatteries()

rednet.open(getWirelessModemSide())
rednet.host(rednetInfo[1], rednetInfo[2])

print("ComputerID : " .. os.getComputerID())
if (AutoDetect) then
	print("AutoDetection : True")
else
	print("AutoDetection : False")
end
print("Protocol: " .. rednetInfo[1])
print("Host: " .. rednetInfo[2])

scr = peripheral.find("monitor")
ScrComputer = term.current()
scr.setTextScale(1)
term.redirect(scr)
term.setCursorBlink(false)
scrW, scrH = term.getSize()

function centerText(energy,yVal)
	local percent =  energy[1] / energy[2] * 100
	length = string.len(textutils.formatTime(os.time(), true) .. " - " .. string.format("%d%%", percent) .. " - " .. getNbBatteries() .. " Batteries")
	minus = math.floor(scrW-length)
	x = math.floor(minus/2)
	scr.setCursorPos(x+1,yVal)
	if os.time() > 18 or os.time() < 6 then
		scr.setTextColor(colors.blue)
	else
		scr.setTextColor(colors.yellow)
	end
	scr.write(textutils.formatTime(os.time(), true))

	scr.setTextColor(colors.white)
	scr.setBackgroundColor(colors.black)
	scr.write(" - ")

	if (percent > 80) then
		scr.setTextColor(colors.green)
	elseif (percent > 60) then
		scr.setTextColor(colors.lime)
	elseif (percent > 40) then
		scr.setTextColor(colors.yellow)
	elseif (percent > 20) then
		scr.setTextColor(colors.orange)
	else
		scr.setTextColor(colors.black)
		scr.setBackgroundColor(colors.red)
	end
	
	scr.write(string.format("%d%%", percent))

	scr.setTextColor(colors.white)
	scr.setBackgroundColor(colors.black)
	scr.write(" - ")

	if (getNbBatteries() <= 0) then
		scr.setTextColor(colors.black)
		scr.setBackgroundColor(colors.red)
	end
	scr.write(getNbBatteries() .. " Batteries")
	scr.setTextColor(colors.white)
	scr.setBackgroundColor(colors.black)
end

local barW = scrW * 0.9
local lastEnergy = 0
function printStatus(energy)
	term.clear()
	term.setCursorPos(1,1)
	centerText(energy, 1)
	term.setCursorPos(1,2)
	term.write("Charge: " .. string.format("%2.1f", energy[1] / 1000000) .. "M EU\n")
	term.setCursorPos(1,3)
	term.write("Capacité: " .. string.format("%2.1f", energy[2] / 1000000) .. "M EU\n")
	printBar(energy)
	term.setTextColor(colors.white)
	term.setBackgroundColor(colors.black)
end

function printBar(energy)
	local val = math.floor((energy[1] / energy[2]) * (scrW - 2) + 0.5)
	local percent =  energy[1] / energy[2] * 100

	scr.setCursorPos(2,5)
	scr.setBackgroundColour(colors.gray)
	scr.write(string.rep(" ", scrW-2))
	scr.setCursorPos(2,5)

	if (percent > 80) then
		scr.setBackgroundColour(colors.green)
	elseif (percent > 60) then
		scr.setBackgroundColour(colors.lime)
	elseif (percent > 40) then
		scr.setBackgroundColour(colors.yellow)
	elseif (percent > 20) then
		scr.setBackgroundColour(colors.orange)
	else
		scr.setBackgroundColour(colors.red)
	end
	scr.write(string.rep(" ", val))
end

while true do
	local totalEnergy = 0
	local totalCapacity = 0
	local energy = {}
	if (AutoDetect) then
		findBatteries()
	end
	for index, batterie in pairs(batteries) do
		local currEU, currEUCap = getBatterieInfo(index)
		totalEnergy = totalEnergy + currEU
		totalCapacity = totalCapacity + currEUCap
		table.insert(energy, { currEU, currEUCap })
	end
	table.insert(energy, 1, totalEnergy)
	table.insert(energy, 2, totalCapacity)
	printStatus(energy)
	rednet.broadcast(energy, "EnergyStatus")
	os.sleep(0.05)
end