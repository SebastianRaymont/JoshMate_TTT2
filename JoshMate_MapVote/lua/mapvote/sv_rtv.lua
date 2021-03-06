util.AddNetworkString("RTV_DoVote")

RTV = {}

RTV.rtv_votes = {}

hook.Add("PlayerSay", "JM_RTV_ChatCommand", function(ply, text, public)
	text = string.lower(text)
    text = string.Trim(text)

	if text == "!rtv" then
		ply:ConCommand("rtv")
	end
end)

concommand.Add("rtv", function(ply, cmd, args)
    if !IsValid(ply) then return end

    local id = ply:SteamID()

    local amount = RTV:GetNecessaryVoteAmount()
    local voteCounts = RTV:CountVotes()

    local msg = ""
    if voteCounts == 0 then
        msg = string.format("[RTV] - (%i/%i) %s",  voteCounts + 1, amount, ply:Nick())
    else
        msg = string.format("[RTV] - (%i/%i) %s",  voteCounts + 1, amount, ply:Nick())
    end

    if RTV:ExistsInTable(ply) then
        ply:ChatPrint(msg)
    else
        RTV:AddVote(ply)
        PrintMessage(HUD_PRINTTALK, msg)
    end

    RTV:StartMapvoteIfNeeded()
end)

function RTV:GetNecessaryVoteAmount()
    local playerCount = #player.GetAll()
    local percentage  = 0.55

    local amount = math.ceil(playerCount * percentage)

    return amount
end

function RTV:ExistsInTable(ply)
    if !IsValid(ply) then return end

    for k,v in pairs(self.rtv_votes) do
        if v == ply then
            return true
        end
    end

    return false
end

function RTV:AddVote(ply) 
    if !IsValid(ply) then return end

    table.insert(RTV.rtv_votes, ply)
end

function RTV:CountVotes()
    local c = 0

    for k,ply in pairs(self.rtv_votes) do
        if IsValid(ply) then
            c = c + 1
        end
    end

    return c
end

function RTV:StartMapvoteIfNeeded()
    if self:CountVotes() >= self:GetNecessaryVoteAmount() then
        if GetRoundState() == ROUND_ACTIVE then
            PrintMessage(HUD_PRINTTALK, "[RTV] - PASSED! The map vote will begin at the end of the round...")
            hook.Add("TTTEndRound", "RTVDelay", function()
                hook.Remove("TTTEndRound", "RTVDelay")
                MapVote:Start()
            end)
        else
            MapVote:Start()
        end
    end
end

function RTV:Reset()
    self.rtv_votes = {}
end