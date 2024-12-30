#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>

public Plugin myinfo = {
    name = "Test Bot & Building Spawner",
    author = "Creeper7",
    description = "Spawns test bots and buildings",
    version = "1.0",
    url = ""
};

public void OnPluginStart() {
    // Bot commands
    RegConsoleCmd("sm_bot", Command_SpawnBot, "Spawns a test bot with normal health");
    RegConsoleCmd("sm_bbot", Command_SpawnCustomBot, "Spawns a test bot with custom health");
    
    // Building commands
    RegConsoleCmd("sm_building", Command_SpawnBuilding, "Spawns a test building");
    RegConsoleCmd("sm_bbuilding", Command_SpawnCustomBuilding, "Spawns a test building with custom health");
}

// Bot Commands
public Action Command_SpawnBot(int client, int args) {
    if (!IsValidClient(client)) return Plugin_Handled;
    
    char className[32];
    if (args < 1) {
        ReplyToCommand(client, "Usage: !bot <class>");
        return Plugin_Handled;
    }
    
    GetCmdArg(1, className, sizeof(className));
    SpawnTestBot(client, className, -1);
    
    return Plugin_Handled;
}

public Action Command_SpawnCustomBot(int client, int args) {
    if (!IsValidClient(client)) return Plugin_Handled;
    
    if (args < 2) {
        ReplyToCommand(client, "Usage: !bbot <class> <health>");
        return Plugin_Handled;
    }
    
    char className[32], healthStr[16];
    GetCmdArg(1, className, sizeof(className));
    GetCmdArg(2, healthStr, sizeof(healthStr));
    
    int health = StringToInt(healthStr);
    if (health <= 0) health = 125;
    
    SpawnTestBot(client, className, health);
    
    return Plugin_Handled;
}

void SpawnTestBot(int client, const char[] className, int customHealth) {
    float clientPos[3], clientAng[3];
    GetClientAbsOrigin(client, clientPos);
    GetClientAbsAngles(client, clientAng);
    
    clientPos[0] += 100.0 * Cosine(DegToRad(clientAng[1]));
    clientPos[1] += 100.0 * Sine(DegToRad(clientAng[1]));
    
    TFClassType botClass = TFClass_Scout;
    
    if (StrEqual(className, "scout", false)) botClass = TFClass_Scout;
    else if (StrEqual(className, "soldier", false)) botClass = TFClass_Soldier;
    else if (StrEqual(className, "pyro", false)) botClass = TFClass_Pyro;
    else if (StrEqual(className, "demoman", false)) botClass = TFClass_DemoMan;
    else if (StrEqual(className, "heavy", false)) botClass = TFClass_Heavy;
    else if (StrEqual(className, "engineer", false)) botClass = TFClass_Engineer;
    else if (StrEqual(className, "medic", false)) botClass = TFClass_Medic;
    else if (StrEqual(className, "sniper", false)) botClass = TFClass_Sniper;
    else if (StrEqual(className, "spy", false)) botClass = TFClass_Spy;
    
    int bot = CreateFakeClient("TestBot");
    if (bot > 0) {
        ChangeClientTeam(bot, GetClientTeam(client) == 2 ? 3 : 2);
        TF2_SetPlayerClass(bot, botClass);
        TF2_RespawnPlayer(bot);
        TeleportEntity(bot, clientPos, clientAng, NULL_VECTOR);
        
        if (customHealth > 0) {
            SetEntityHealth(bot, customHealth);
        }
        
        SetEntProp(bot, Prop_Send, "m_bIsMiniBoss", true);
        SetEntProp(bot, Prop_Send, "m_iTeamNum", GetClientTeam(client) == 2 ? 3 : 2);
    }
}

// Building Commands
public Action Command_SpawnBuilding(int client, int args) {
    if (!IsValidClient(client)) return Plugin_Handled;
    SpawnTestBuilding(client, 100);
    return Plugin_Handled;
}

public Action Command_SpawnCustomBuilding(int client, int args) {
    if (!IsValidClient(client)) return Plugin_Handled;
    
    if (args < 1) {
        ReplyToCommand(client, "Usage: !bbuilding <health>");
        return Plugin_Handled;
    }
    
    char healthStr[16];
    GetCmdArg(1, healthStr, sizeof(healthStr));
    int health = StringToInt(healthStr);
    
    if (health <= 0) health = 100;
    SpawnTestBuilding(client, health);
    
    return Plugin_Handled;
}

void SpawnTestBuilding(int client, int health) {
    float clientPos[3], clientAng[3];
    GetClientAbsOrigin(client, clientPos);
    GetClientAbsAngles(client, clientAng);
    
    clientPos[0] += 100.0 * Cosine(DegToRad(clientAng[1]));
    clientPos[1] += 100.0 * Sine(DegToRad(clientAng[1]));
    
    int building = CreateEntityByName("obj_dispenser");
    if (IsValidEntity(building)) {
        DispatchKeyValue(building, "defaultupgrade", "0");
        SetEntProp(building, Prop_Send, "m_iHighestUpgradeLevel", 1);
        SetEntProp(building, Prop_Data, "m_takedamage", 2);
        SetEntProp(building, Prop_Send, "m_iTeamNum", GetClientTeam(client) == 2 ? 3 : 2);
        
        DispatchSpawn(building);
        TeleportEntity(building, clientPos, clientAng, NULL_VECTOR);
        SetVariantInt(health);
        AcceptEntityInput(building, "SetHealth");
    }
}

bool IsValidClient(int client) {
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}