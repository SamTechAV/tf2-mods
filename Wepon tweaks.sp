#include <sourcemod>
#include <tf2_stocks>
#include <tf2items>
#include <tf2attributes>
#include <sdkhooks>

#define DEAD_RINGER_ID 59
#define SHIELD_BASH_CRIT_CHECK 1
#define CABER_ID 307
#define BISON_ID 442
#define RECHARGE_PERCENT 0.25
#define EXTRA_DR_RESISTANCE 0.10
#define BASE_RECHARGE_RATE 1.0
#define CABER_RELOAD_DELAY 1.0

bool g_bCaberReloading[MAXPLAYERS+1];

public Plugin myinfo = {
    name = "Weapon Tweaks",
    author = "Creeper7",
    description = "Tweaks for Dead Ringer, Caber, and Bison",
    version = "1.7",
    url = ""
};

public void OnMapStart() {
    PrecacheSound("player/recharged.wav");
}

public void OnPluginStart() {
    HookEvent("player_death", Event_PlayerDeath);
    
    for(int i = 1; i <= MaxClients; i++) {
        if(IsClientInGame(i)) {
            SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
            g_bCaberReloading[i] = false;
        }
    }
}

public void OnClientPutInServer(int client) {
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    CreateTimer(0.5, Timer_ApplyBaseRecharge, client);
    CreateTimer(0.5, Timer_ApplyWeaponAttributes, client);
    g_bCaberReloading[client] = false;
}

public Action Timer_ApplyBaseRecharge(Handle timer, any client) {
    if (IsValidClient(client)) {
        int watch = GetPlayerWeaponSlot(client, 4);
        if (IsValidEntity(watch) && GetEntProp(watch, Prop_Send, "m_iItemDefinitionIndex") == DEAD_RINGER_ID) {
            TF2Attrib_SetByName(watch, "mult cloak meter regen rate", BASE_RECHARGE_RATE);
        }
    }
    return Plugin_Continue;
}

public Action Timer_ApplyWeaponAttributes(Handle timer, any client) {
    if (!IsValidClient(client)) return Plugin_Continue;
    
    // Apply Bison damage bonus
    int secondary = GetPlayerWeaponSlot(client, 1);
    if (IsValidEntity(secondary)) {
        int secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
        if (secondaryIndex == BISON_ID) {
            TF2Attrib_SetByName(secondary, "damage bonus", 0.213); // Sets base damage to 50
        }
    }
    
    return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom) {
    if (!IsValidClient(victim)) {
        return Plugin_Continue;
    }
    
    if (TF2_GetPlayerClass(victim) == TFClass_Spy) {
        int watch = GetPlayerWeaponSlot(victim, 4);
        if (IsValidEntity(watch) && GetEntProp(watch, Prop_Send, "m_iItemDefinitionIndex") == DEAD_RINGER_ID) {
            if (GetEntProp(victim, Prop_Send, "m_bFeignDeathReady") == 1 && 
                damage >= GetClientHealth(victim)) {
                damage *= (1.0 - EXTRA_DR_RESISTANCE);
                
                PrintCenterText(victim, "⚔️ +10%% DAMAGE RESISTANCE ACTIVE ⚔️");
                PrintToChat(victim, "\x07FFD700[Mod] \x0732CD32+10%% Damage Resistance\x07FFFFFF activated!");
                PrintHintText(victim, "+10%% Damage Resistance Active");
                
                CreateTimer(0.5, Timer_NotifyResistanceOff, victim);
                return Plugin_Changed;
            }
        }
    }
    
    if (!IsValidClient(attacker) || !IsValidEntity(weapon)) {
        return Plugin_Continue;
    }
    
    int weaponIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
    if (weaponIndex == CABER_ID) {
        bool isCharging = TF2_IsPlayerInCondition(attacker, TFCond_Charging);
        bool hasShield = false;
        int secondary = GetPlayerWeaponSlot(attacker, 1);
        
        if (IsValidEntity(secondary)) {
            int secondaryIndex = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
            hasShield = (secondaryIndex == 131 || secondaryIndex == 406 || secondaryIndex == 1099);
        }
        
        if (isCharging && hasShield) {
            TF2_AddCondition(victim, TFCond_MarkedForDeath, 0.1);
            damage *= 1.35;
            return Plugin_Changed;
        }
    }
    
    return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = GetClientOfUserId(event.GetInt("userid"));
    
    if (!IsValidClient(attacker) || !IsValidClient(victim) || attacker == victim) {
        return Plugin_Continue;
    }
    
    // Check for Dead Ringer
    int watch = GetPlayerWeaponSlot(attacker, 4);
    if (IsValidEntity(watch)) {
        int watchIndex = GetEntProp(watch, Prop_Send, "m_iItemDefinitionIndex");
        if (watchIndex == DEAD_RINGER_ID) {
            float currentCloak = GetEntPropFloat(attacker, Prop_Send, "m_flCloakMeter");
            float newCloak = currentCloak + (100.0 * RECHARGE_PERCENT);
            if (newCloak > 100.0) newCloak = 100.0;
            
            SetEntPropFloat(attacker, Prop_Send, "m_flCloakMeter", newCloak);
            PrintToChat(attacker, "\x07FFD700[DR] \x0732CD32+25%% Dead Ringer\x07FFFFFF recharged! (\x0732CD32%.0f%%\x07FFFFFF)", newCloak);
        }
    }
    
    // Check for Caber
    int melee = GetPlayerWeaponSlot(attacker, 2);
    if (IsValidEntity(melee)) {
        int meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
        if (meleeIndex == CABER_ID) {
            g_bCaberReloading[attacker] = true;
            
            // Start with detonated state to prevent immediate explosion
            SetEntProp(melee, Prop_Send, "m_bBroken", 1);
            SetEntProp(melee, Prop_Send, "m_iDetonated", 1);
            
            // Create timer to finish reload
            CreateTimer(CABER_RELOAD_DELAY, Timer_FinishCaberReload, attacker);
            
            // Remove penalties and previous attributes
            TF2Attrib_RemoveByName(melee, "damage penalty");
            TF2Attrib_RemoveByName(melee, "fire rate penalty");
            TF2Attrib_RemoveByName(melee, "mod crit while airborne");
            TF2Attrib_RemoveByName(melee, "mod mini-crit airborne");
            TF2Attrib_RemoveByName(melee, "critboost on kill");
            TF2Attrib_RemoveByName(melee, "damage bonus");
            
            // Set new base damage (125)
            TF2Attrib_SetByName(melee, "damage bonus", 0.534);  // Sets base damage to 125
            TF2Attrib_SetByName(melee, "effect bar recharge rate increased", 0.0);
            
            // Force weapon switch to update model
            int primaryWeapon = GetPlayerWeaponSlot(attacker, 0);
            if (IsValidEntity(primaryWeapon)) {
                SetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon", primaryWeapon);
                CreateTimer(0.1, Timer_SwitchBackToMelee, attacker);
            }
            
            PrintToChat(attacker, "\x07FFD700[Mod] \x0732CD32Caber\x07FFFFFF is \x07FF4500reloading\x07FFFFFF!");
            PrintCenterText(attacker, "🗡️ CABER RELOADING... 🗡️");
        }
    }
    
    return Plugin_Continue;
}

public Action Timer_FinishCaberReload(Handle timer, any client) {
    if (!IsValidClient(client)) return Plugin_Continue;
    
    int melee = GetPlayerWeaponSlot(client, 2);
    if (IsValidEntity(melee)) {
        int meleeIndex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
        if (meleeIndex == CABER_ID) {
            // Reset explosion state
            SetEntProp(melee, Prop_Send, "m_bBroken", 0);
            SetEntProp(melee, Prop_Send, "m_iDetonated", 0);
            g_bCaberReloading[client] = false;
            
            PrintToChat(client, "\x07FFD700[Mod] \x0732CD32Caber\x07FFFFFF is now \x0732CD32ready\x07FFFFFF!");
            PrintCenterText(client, "🗡️ CABER READY! 🗡️");
            EmitSoundToClient(client, "player/recharged.wav");
        }
    }
    return Plugin_Continue;
}

public Action Timer_SwitchBackToMelee(Handle timer, any client) {
    if (IsValidClient(client)) {
        int melee = GetPlayerWeaponSlot(client, 2);
        if (IsValidEntity(melee)) {
            SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", melee);
        }
    }
    return Plugin_Continue;
}

public Action Timer_NotifyResistanceOff(Handle timer, any client) {
    if (IsValidClient(client)) {
        PrintCenterText(client, "❌ DAMAGE RESISTANCE ENDED ❌");
        PrintToChat(client, "\x07FFD700[Mod] \x07FF4500+10%% Damage Resistance\x07FFFFFF deactivated!");
        PrintHintText(client, "Damage Resistance Deactivated");
    }
    return Plugin_Continue;
}

bool IsValidClient(int client) {
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}