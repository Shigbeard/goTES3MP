-- IrcBridge.lua -*-lua-*-
-- "THE BEER-WARE LICENCE" (Revision 42):
-- <mail@michael-fitzmayer.de> wrote this file.  As long as you retain
-- this notice you can do whatever you want with this stuff. If we meet
-- some day, and you think this stuff is worth it, you can buy me a beer
-- in return.  Michael Fitzmayer

require("color")
local irc = require("irc")
local cjson = require("cjson")

local goTES3MP = require("custom.goTES3MP.main")
local goTES3MPSync = require("custom.goTES3MP.sync")
local goTES3MPUtils = require("custom.goTES3MP.utils")
local goTES3MPCommands = require("custom.goTES3MP.commands")

local IrcBridge = {}

IrcBridge.version = "v4.0.5-goTES3MP"
IrcBridge.scriptName = "IrcBridge"
IrcBridge.debugMode = false

IrcBridge.defaultConfig = {
    nick = "",
    server = "",
    port = "6667",
    password = "",
    nspasswd = "",
    systemchannel = "#",
    nickfilter = "",
    discordColor = "#825eed",
    ircColor = "#5D9BEE"
}

IrcBridge.config = DataManager.loadConfiguration(IrcBridge.scriptName, IrcBridge.defaultConfig)

if (IrcBridge.config == IrcBridge.defaultConfig) then
    tes3mp.LogMessage(enumerations.log.WARN, "IrcBridge configuration has been generated,")
    tes3mp.StopServer(0)
end

if (IrcBridge.config.nick == "" or IrcBridge.config.systemchannel == "" or IrcBridge.config.systemchannel == "#") then
    tes3mp.LogMessage(
        enumerations.log.ERROR,
        "IrcBridge has not been configured correctly." .. "\n" .. "nick, server, and systemchannel are required."
    )
    tes3mp.StopServer(0)
end

local nick = IrcBridge.config.nick
local server = IrcBridge.config.server
local nspasswd = IrcBridge.config.nspasswd
local password = IrcBridge.config.password
local systemchannel = IrcBridge.config.systemchannel
local nickfilter = IrcBridge.config.nickfilter
local discordColor = IrcBridge.config.discordColor
local ircColor = IrcBridge.config.ircColor
local port = IrcBridge.config.port
IRCTimerId = nil

local s = irc.new {nick = nick}
if password ~= "" then
    s:connect(
        {
            host = server,
            port = port,
            password = password,
            timeout = 120,
            secure = false
        }
    )
else
    s:connect(server, port)
end
nspasswd = "identify " .. nspasswd
s:sendChat("NickServ", nspasswd)
s:join(systemchannel)
local lastMessage = ""

IrcBridge.RecvMessage = function()
    s:hook(
        "OnChat",
        function(user, systemchannel, message)
            if message ~= lastMessage then
                if IrcBridge.debugMode then
                    print("IRCDebug: " .. message)
                end

                local responce = goTES3MPUtils.isJsonValidDecode(message)
                -- Unfinishedd
                if responce.Status == "Pong" and WaitingForSync then
                    goTES3MPSync.GotSync(responce.ServerID, responce.SyncID)
                end
                if
                    responce.method == "Command" and responce.data["replyChannel"] ~= nil and
                        responce.data["Command"]
                 then
                    goTES3MPCommands.main(responce.data["TargetPlayer"],responce.data["Command"],responce.data["CommandArgs"], responce.data["replyChannel"])
                end
                if responce.method == "DiscordChat" or responce.method == "IRC" then
                    for pid, player in pairs(Players) do
                        if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
                            IrcBridge.ChatMessage(pid, responce)
                        end
                    end
                end
                if responce.method == "VPNCheck" then
                    if responce.data["kickPlayer"] ~= nil and responce.data["kickPlayer"] == "yes" then
                        pid = responce.data["playerpid"]
                        if tes3mp.GetName(pid) ~= nil then
                            playerName = tes3mp.GetName(pid)
                            tes3mp.SendMessage(pid, playerName .. " was kicked for trying to use a VPN.\n", true, false)
                            tes3mp.Kick(pid)

                            local messageJson = {
                                method = "rawDiscord",
                                source = "TES3MP",
                                serverid = GOTES3MPServerID,
                                syncid = GoTES3MPSyncID,
                                data = {
                                    channel = GoTES3MP_DiscordChannel,
                                    server = GoTES3MP_DiscordServer,
                                    message = "**"..playerName.." was kicked for trying to connect with a VPN.".."**"
                                }
                            }

                            IrcBridge.SendSystemMessage(cjson.encode(messageJson))
                        end
                    end
                end
            end
            lastMessage = message
        end
    )

    tes3mp.RestartTimer(IRCTimerId, time.seconds(1))
end

IrcBridge.ChatMessage = function(pid, responce)
    local wherefrom = ""
    if responce.method == "DiscordChat" then
        wherefrom = discordColor .. "[" .. responce.source .. "]" .. color.Default
    elseif responce.method == "IRC" then
        wherefrom = ircColor .. "[" .. responce.source .. "]" .. color.Default
    else
        wherefrom = color.Default .. "[" .. responce.source .. "]" .. color.Default
    end

    if responce.data["RoleColor"] ~= "" and responce.data["RoleColor"] ~= "" then
        local staffRole = "#" .. responce.data["RoleColor"] .. "[" .. responce.data["RoleName"] .. "]" .. color.Default
        tes3mp.SendMessage(
            pid,
            wherefrom .. " " .. staffRole .. " " .. responce.data["User"] .. ": " .. responce.data["Message"] .. "\n",
            false
        )
    else
        tes3mp.SendMessage(
            pid,
            wherefrom .. " " .. responce.data["User"] .. ": " .. responce.data["Message"] .. "\n",
            false
        )
    end
end

IrcBridge.SendSystemMessage = function(message)
    if message ~= lastMessage then
        s:sendChat(systemchannel, message)
        lastMessage = message
    end
end

function OnIRCUpdate()
    IrcBridge.RecvMessage()
    s:think()
end

customEventHooks.registerValidator(
    "OnServerInit",
    function()
        IRCTimerId = tes3mp.CreateTimer("OnIRCUpdate", time.seconds(1))
    end
)

customEventHooks.registerValidator(
    "OnServerInit",
    function()
        tes3mp.StartTimer(IRCTimerId)
    end
)

customEventHooks.registerValidator(
    "OnServerExit",
    function()
        tes3mp.StopTimer(IRCTimerId)
        s:shutdown()
    end
)
return IrcBridge