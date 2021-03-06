util.AddNetworkString("MapVote_Start")
util.AddNetworkString("MapVote_Stop")
util.AddNetworkString("MapVote_End")
util.AddNetworkString("MapVote_UpdateFromClient")
util.AddNetworkString("MapVote_UpdateToAllClient")

net.Receive("MapVote_UpdateFromClient", function(len, ply)
    if MapVote.active then
        local id = net.ReadUInt(32)
        net.Start("MapVote_UpdateToAllClient")
        net.WriteEntity(ply)
        net.WriteUInt(id, 32)
        net.Broadcast()

        MapVote.votes[ply:UniqueID()] = id
    end
end)

function MapVote:Start(voteTime)
    if self.runs then return end

    self:Init() -- init server MapVote

    MapVote.voteTime = voteTime and voteTime or self.config.voteTime

    net.Start("MapVote_Start")
    net.WriteUInt(MapVote.voteTime, 16)
    net.WriteTable(MapVote.maps)
    net.Broadcast()

    timer.Create("MapVoteWinnerCheck", MapVote.voteTime, 1, function()
        MapVote.active = false

        local voteResults = {}

        -- initialize 
        for k, map in pairs(MapVote.maps) do
            voteResults[k] = 0 
        end

        for plyId, votedButton in pairs(MapVote.votes) do
            voteResults[votedButton] = voteResults[votedButton] + 1
        end

        local winnerKey = table.GetWinningKey(voteResults)
        local winnerValue = voteResults[winnerKey]

        -- search for all winner votes
        local winners = {}
        local max = 0
        for k, v in pairs(voteResults) do
            if v > max then
                max = v
                winners = {}
            end

            if v == max then
                table.insert(winners, k)
            end
        end

        local winner = table.Random(winners)
        local mapName = MapVote.maps[winner]

        net.Start("MapVote_End")
        net.WriteUInt(winner, 32)
        net.Broadcast()

        timer.Simple(5, function()
            RunConsoleCommand("changelevel", mapName)
        end)
    end)
end

function MapVote:Stop()
    if not self.runs then return end

    net.Start("MapVote_Stop")
    net.Broadcast()
    timer.Stop("MapVoteWinnerCheck")
    PrintMessage(HUD_PRINTTALK, "The mapvote was cancled by an admin")
    self.runs = false
end

function MapVote:InitConfig()
    local defaultConfig = {
        voteTime = 30,
        mapsToVote = 15,
        mapPrefixes = {"ttt_"},
        mapExcludes = {}
    }
    self.config = defaultConfig

    ConfigHelper:CreateConfigFolderIfNotExists()

    if file.Exists("JM_mapvote/config.txt", "DATA") then
        self.config = ConfigHelper:ReadConfig("config")

        if not self:ConfigIsValid() then
            self.config = defaultConfig
        end
    end

    ConfigHelper:WriteConfig("config", self.config)
end

function MapVote:ConfigIsValid()
    if not self.config then 
        return false 
    end

    return true
end

function MapVote:GetRandomMaps()
    local maps = file.Find("maps/*.bsp", "GAME")

    local result = {}

    local i = 0
    local max = self.config.mapsToVote

    for k, map in RandomPairs(maps) do
        if i >= max then break end
        local mapstr = map:sub(1, -5)

        -- using this to get only maps which have no mapicons (need this when I create mapicons :D)
        --local a = file.Exists("maps/thumb/" .. mapstr .. ".png", "GAME")
        --local b = file.Exists("maps/" .. mapstr .. ".png", "GAME")

        local notExclude = not self:IsExlude(mapstr)

        if self:HasPrefix(mapstr) and notExclude then 
            table.insert(result, mapstr)
            i = i + 1
        end
    end

    return result
end

function MapVote:HasPrefix(map)
    local prefixes = self.config.mapPrefixes
    if table.Count(prefixes) == 0 then
        return true
    end

    for k, prefix in pairs(prefixes) do
        if string.StartWith(map, prefix) then
            return true
        end
    end

    return false
end

function MapVote:IsExlude(map)
    local excludes = self.config.mapExcludes
    if table.Count(excludes) == 0 then
        return false
    end

    for k, exclude in pairs(excludes) do
        if map == exclude then
            return true
        end
    end

    return false
end

hook.Add("Initialize", "Initialize mapvote config", function()
    MapVote:InitConfig()
end )

hook.Add("Initialize", "MapChangeInitHook", function()
    if GAMEMODE_NAME == "terrortown" then
        function CheckForMapSwitch()
            local rounds_left = math.max(0, GetGlobalInt("ttt_rounds_left", 6) - 1)
            SetGlobalInt("ttt_rounds_left", rounds_left)

            local time_left = (GetConVar("ttt_time_limit_minutes"):GetInt() * 60) - 2 -- a bit delay

            if rounds_left <= 0 or time_left <= 0 then
                timer.Stop("end2prep")
                MapVote:Start()
            end
        end
    end
end )