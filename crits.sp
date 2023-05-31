#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <tf2attributes>
#include <tf2items>
#include <sendproxy>

new bool:isReady[MAXPLAYERS + 1] = { false, ... };
Handle g_hSdkEquipWearable;
Handle g_hSDKPlayGesture;
bool g_bApply[MAXPLAYERS + 1];
new bool:g_bHeadshot[MAXPLAYERS + 1] = { false, ... };
new bool:g_bHeadshoted[MAXPLAYERS + 1] = { false, ... };
new bool:g_bIsCrit[MAXPLAYERS + 1] = { false, ... };
new bool:g_bAutoSwitchTeams[MAXPLAYERS + 1] = { false, ... };
new bool:g_bReloading[MAXPLAYERS + 1] = { false, ... };
new bool:g_bIsHostile[MAXPLAYERS + 1] = { false, ... };
new bool:g_bIsHappy[MAXPLAYERS + 1] = { false, ... };
new bool:g_bShotByImpostor[MAXPLAYERS + 1] = { false , ... };
new bool:g_bStabbedByImpostor[MAXPLAYERS + 1] = { false , ... };
int shotByWhatImpostor[MAXPLAYERS + 1] = { -1 , ... };
new Handle:sv_cheats = INVALID_HANDLE;
new Handle:sway = INVALID_HANDLE;
new Handle:interp = INVALID_HANDLE;
// this addon fixes incorrect weapon sounds, and frozen reload animations. it also increases crit rate for some weapons (i think)
#define TF_DEATHFLAG_MINIBOSS (1 << 9)
public Plugin:myinfo = 
{
	name = "[TF2] Enhanced Weapon Crap",
	author = "Seamusmario",
	description = "Enhanced Weapon Crap.",
	version = "Alpha",
	url = "https://steamcommunity.com/groups/SEAMSERVER"
}

// most of this was taken from the forums. i don't really own most of the code.
// some of it i wrote from scratch
// credit to everybody


new Handle:cvarForceMVM, Handle:cvarForceHuman;
public OnPluginStart()
{
	sv_cheats = FindConVar("sv_cheats");
    sway = FindConVar("cl_wpn_sway_scale");
    interp = FindConVar("cl_wpn_sway_interp");
	AddNormalSoundHook(CritWeaponSH);
	Handle hConf = LoadGameConfigFile("tf2items.randomizer");
	HookEvent("post_inventory_application", Event_InvApp, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
    HookEvent("player_team", Event_PlayerTeam);
	
	RegConsoleCmd("sm_joinblu", Command_JoinBlue);
	RegConsoleCmd("sm_joinblue", Command_JoinBlue);
	RegConsoleCmd("sm_joinred", Command_JoinRed);
	RegConsoleCmd("sm_blu", Command_JoinBlue);
	RegConsoleCmd("sm_blue", Command_JoinBlue);
	RegConsoleCmd("sm_red", Command_JoinRed);
	RegConsoleCmd("sm_beblu", Command_JoinBlue);
	RegConsoleCmd("sm_beblue", Command_JoinBlue);
	RegConsoleCmd("sm_bered", Command_JoinRed);
	RegAdminCmd("sm_behappy", Command_Happy, ADMFLAG_CHEATS);
	RegAdminCmd("sm_behuman", Command_Human, ADMFLAG_CHEATS);
	RegAdminCmd("sm_beimpostor", Command_FriendlyFire, ADMFLAG_CHEATS);
	RegAdminCmd("sm_beimposter", Command_FriendlyFire, ADMFLAG_CHEATS);
    HookEvent("player_team", Event_PlayerTeam);
	HookEntityOutput("team_control_point", "OnCapTeam2", OnGateCapture);
	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CTFPlayer::EquipWearable"))PrintToServer("[PlayerModelRandomizer] Failed to set EquipWearable from conf!");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSdkEquipWearable = EndPrepSDKCall();
	
	cvarForceMVM = CreateConVar("sm_crits_force_mvm", "1", "If on, MVM will be enabled regardless of the map.", FCVAR_NONE, true, 0.0, true, 1.0);
	cvarForceHuman = CreateConVar("sm_crits_force_humans", "0", "If on, MVM will be enabled regardless of the map.", FCVAR_NONE, true, 0.0, true, 1.0);
    new index = -1;
    while ((index = FindEntityByClassname(index, "tf_gamerules")) != -1)
    {
        SendProxy_Hook(index, "m_bPlayingMannVsMachine", Prop_Int, ProxyCallback);
        SendProxy_Hook(index, "m_bInSetup", Prop_Int, ProxyCallback2);
    }
	delete hConf;
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsClientReplay(i) && !IsClientSourceTV(i))
        {
		    SendProxy_Hook(i, "m_bIsMiniBoss", Prop_Int, MiniBossProxy);
            //SendProxy_Hook(i, "m_nSkin", Prop_Int, SkinProxy);
		    SendProxy_Hook(i, "m_iTeamNum", Prop_Int, TeamProxyClient);
            //SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
            //SDKHook(i, SDKHook_TraceAttack, Client_TraceAttack);
        }
    }
}


public Action:MiniBossProxy(entity, const String:propName[], &iValue, element)
{
	//PrintToServer("[debug] Action:MiniBossProxy(%d, '%s', %d)",
	//	entity,
	//	propName,
	//	iValue);
    
    decl String:m_plrModelName[PLATFORM_MAX_PATH];
    GetEntPropString(entity, Prop_Data, "m_ModelName", m_plrModelName, sizeof(m_plrModelName));
    if (StrContains(m_plrModelName,"/bot_") != -1 && StrContains(m_plrModelName,"boss") == -1) {

	    iValue = 0;

    } else if (StrContains(m_plrModelName,"/bot_") != -1 && (StrContains(m_plrModelName,"boss") != -1 || StrContains(m_plrModelName,"buster") != -1)) {
    
	    iValue = 1;

    } else {

	    iValue = 1;

    }
	return Plugin_Changed;
}

public Action:ProxyCallback(entity, const String:propname[], &iValue, element)
{
    //Set iValue to whatever you want to send to clients
    iValue = GetConVarInt(cvarForceMVM);
    return Plugin_Changed;
} 
public Action:ProxyCallback2(entity, const String:propname[], &iValue, element)
{
    //Set iValue to whatever you want to send to clients
    iValue = 1;
    return Plugin_Changed;
} 
public OnMapStart()
{
    new index = -1;
    while ((index = FindEntityByClassname(index, "tf_gamerules")) != -1)
    {
        SendProxy_Hook(index, "m_bPlayingMannVsMachine", Prop_Int, ProxyCallback);
        SendProxy_Hook(index, "m_bInSetup", Prop_Int, ProxyCallback2);
    }
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsClientReplay(i) && !IsClientSourceTV(i))
        {   
		    SendProxy_Hook(i, "m_bIsMiniBoss", Prop_Int, MiniBossProxy);
            //SendProxy_Hook(i, "m_nSkin", Prop_Int, SkinProxy);
		    SendProxy_Hook(i, "m_iTeamNum", Prop_Int, TeamProxyClient);
            //SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
            //SDKHook(i, SDKHook_TraceAttack, Client_TraceAttack);
        }
    }
}

public OnClientDisconnect_Post(client)
{
	g_bStabbedByImpostor[client] = false;
	g_bShotByImpostor[client] = false;
	g_bIsHappy[client] = false;
	g_bIsHostile[client] = false;
	g_bReloading[client] = false;
	g_bAutoSwitchTeams[client] = false;
	g_bIsCrit[client] = false;
	g_bHeadshot[client] = false;
	g_bHeadshoted[client] = false;
}
public OnClientPutInServer(client)
{
	//PrintToServer("[debug] OnClientPutInServer(%d)",
	//	client);
	OnClientDisconnect_Post(client);
	SendProxy_Hook(client, "m_bIsMiniBoss", Prop_Int, MiniBossProxy);
    //SendProxy_Hook(client, "m_nSkin", Prop_Int, SkinProxy);
	SendProxy_Hook(client, "m_iTeamNum", Prop_Int, TeamProxyClient);
    //SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    //SDKHook(client, SDKHook_TraceAttack, Client_TraceAttack);
	SetEntProp(client, Prop_Send, "m_nCurrency", 1600);
	new entflags = GetEntityFlags( client );
	if (!IsFakeClient(client)) {
		SetEntityFlags( client, entflags|FL_FAKECLIENT );
		ChangeClientTeam( client, GetRandomInt(2,3) );
		SetEntityFlags( client, entflags&~FL_FAKECLIENT );
	}
    ShowClassPanel(client);
}

public Event_PlayerTeam(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    new userid = GetEventInt(hEvent, "userid");
    new team = GetEventInt(hEvent, "team");
    new client = GetClientOfUserId(userid);
}

public Action:TeamProxyClient(entity, const String:propName[], &iValue, element)
{
	//PrintToServer("[debug] Action:TeamProxyClient(%d, '%s', %d)",
	//	entity,
	//	propName,
	//	iValue);
	
    decl String:m_plrModelName[PLATFORM_MAX_PATH];
    GetEntPropString(entity, Prop_Data, "m_ModelName", m_plrModelName, sizeof(m_plrModelName));
	new team = GetEntProp(entity, Prop_Send, "m_iTeamNum") - 2;
	if (!IsFakeClient(entity)) {
		if (StrContains(m_plrModelName,"/bot_") != -1 && StrContains(m_plrModelName,"boss") == -1) {
			iValue = 3;
			SetEntProp(entity, Prop_Send, "m_bForcedSkin", 1);
			SetEntProp(entity, Prop_Send, "m_nForcedSkin", team);
			return Plugin_Changed;
		} else if (StrContains(m_plrModelName,"/bot_") != -1 && StrContains(m_plrModelName,"boss") != -1) {
			iValue = 3;
			SetEntProp(entity, Prop_Send, "m_bForcedSkin", 1);
			SetEntProp(entity, Prop_Send, "m_nForcedSkin", team);
			return Plugin_Changed;
		} else {
			SetEntProp(entity, Prop_Send, "m_bForcedSkin", 0);
			SetEntProp(entity, Prop_Send, "m_nForcedSkin", 0);
			return Plugin_Continue;
		}
	} else {
		SetEntProp(entity, Prop_Send, "m_bForcedSkin", 0);
	}
}
/*
public Action:SkinProxy(entity, const String:propName[], &iValue, element)
{
	//PrintToServer("[debug] Action:SkinProxy(%d, '%s', %d)",
	//	entity,
	//	propName,
	//	iValue);
	
//	PrintToChatAll("%d", entity);
	new team = GetEntProp(entity, Prop_Send, "m_iTeamNum") - 3;
    decl String:m_plrModelName[PLATFORM_MAX_PATH];
    GetEntPropString(entity, Prop_Data, "m_ModelName", m_plrModelName, sizeof(m_plrModelName));
    if (StrContains(m_plrModelName,"/bot_") != -1 && StrContains(m_plrModelName,"boss") == -1) {
	    iValue = team;
	    return Plugin_Changed;
    } else if (StrContains(m_plrModelName,"/bot_") != -1 && StrContains(m_plrModelName,"boss") != -1) {
        iValue = team;
	    return Plugin_Changed;
    } else {
        return Plugin_Continue;
    }
}
*/
public Action RemoveBody(Handle timer, any client)
{
	int BodyRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if(IsValidEdict(BodyRagdoll))
	{
		AcceptEntityInput(BodyRagdoll, "kill");
	}
}
public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int death_flags = GetEventInt(event, "death_flags");
	if ((death_flags & TF_DEATHFLAG_MINIBOSS) == 0) {
		SetEventInt(event, "death_flags", (death_flags | TF_DEATHFLAG_MINIBOSS));
	}
	new money = GetEntProp(attacker, Prop_Send, "m_nCurrency");
	if (IsValidClient(attacker)) {
		SetEntProp(attacker, Prop_Send, "m_nCurrency", money+60);
	}
    if (IsValidEntity(shotByWhatImpostor[client])) { 
        attacker = GetClientUserId(shotByWhatImpostor[client]);
        SetEventInt(event, "attacker", GetClientUserId(shotByWhatImpostor[client]));
        new hClientWeapon = GetEntPropEnt(shotByWhatImpostor[client], Prop_Send, "m_hActiveWeapon");
        char clsname[256]; 
        GetEntityClassname(hClientWeapon,clsname,sizeof(clsname));
        
        ReplaceString(clsname, sizeof(clsname), "tf_weapon_", "");
        SetEventString(event, "weapon", clsname);
    }
    if (g_bStabbedByImpostor[client]) {
		SetEventInt(event, "customkill", TF_CUSTOM_BACKSTAB);
		SetEventString(event, "weapon", "backstab");
    }
}

public Action Event_PlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsValidEntity(shotByWhatImpostor[client])) { 
        attacker = GetClientUserId(shotByWhatImpostor[client]);
        SetEventInt(event, "attacker", GetClientUserId(shotByWhatImpostor[client]));
        new hClientWeapon = GetEntPropEnt(shotByWhatImpostor[client], Prop_Send, "m_hActiveWeapon");
        char clsname[256]; 
        GetEntityClassname(hClientWeapon,clsname,sizeof(clsname));
        
        ReplaceString(clsname, sizeof(clsname), "tf_weapon_", "");
        SetEventString(event, "weapon", clsname);
    }
}
public Action Client_TraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{

    int whoShotMe = -1;
    if (g_bIsHostile[attacker]) {
        shotByWhatImpostor[victim] = attacker;
    }
    if (g_bIsHostile[attacker] && GetClientTeam(victim) == GetClientTeam(attacker)) {
        SDKHooks_TakeDamage(victim,inflictor,victim,damage,damagetype)
        if (!g_bShotByImpostor[victim]) {
            g_bShotByImpostor[victim] = true;
            CreateTimer(0.01, Timer_SetNotShot, victim, TIMER_DATA_HNDL_CLOSE);
        }
        return Plugin_Changed;
    } else if (g_bIsHostile[victim] && GetClientTeam(attacker) == GetClientTeam(victim)) {
        SDKHooks_TakeDamage(victim,inflictor,victim,damage,damagetype)
        if (!g_bShotByImpostor[victim]) {
            g_bShotByImpostor[victim] = true;
            CreateTimer(0.01, Timer_SetNotShot, victim, TIMER_DATA_HNDL_CLOSE);
        }
        return Plugin_Changed;
    } else {
        shotByWhatImpostor[victim] = -1;
        return Plugin_Changed;
    }
    return Plugin_Continue;
}

public void Event_InvApp(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
    if (!g_bAutoSwitchTeams[client]) {
		CreateTimer(0.01, Timer_SetPlaybackRate, client, TIMER_REPEAT);
		
        g_bAutoSwitchTeams[client] = true;
	}
	shotByWhatImpostor[client] = -1;
    SetEntProp(client, Prop_Send, "m_nRenderFX", 0);
    //TF2Attrib_SetByName(client, "mod see enemy health", 1.0);
    CreateTimer(0.1, Timer_SetReady, client, TIMER_DATA_HNDL_CLOSE); 
    isReady[client] = false;
	TF2Attrib_SetByName(client, "deploy time decreased", 1.4);
    if (g_bIsHostile[client]) {
        SetEntProp(client, Prop_Data, "m_CollisionGroup", 9);
	    TF2Attrib_SetByName(client, "dmg taken from bullets reduced", 0.7);
	    TF2Attrib_SetByName(client, "dmg taken from blast reduced", 0.7);
	    TF2Attrib_SetByName(client, "dmg taken from crit reduced", 0.7);
	    TF2Attrib_SetByName(client, "dmg taken from fire reduced", 0.7);
	    TF2Attrib_SetByName(client, "health regen", 10.0);
    } else {
        SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
    	//TF2Attrib_RemoveByName(client, "dmg taken from bullets reduced");
	    //TF2Attrib_RemoveByName(client, "dmg taken from blast reduced");
	    //TF2Attrib_RemoveByName(client, "dmg taken from crit reduced");
	    //TF2Attrib_RemoveByName(client, "dmg taken from fire reduced");
	    //TF2Attrib_RemoveByName(client, "health regen");    
    }
    g_bHeadshot[client] = false;
    g_bHeadshoted[client] = false;
    g_bShotByImpostor[client] = false;
    g_bStabbedByImpostor[client] = false;
	if (g_bApply[client])
	{
        SetEntProp(client, Prop_Send, "m_nRenderFX", 0);
        SetVariantString("");
	    AcceptEntityInput(client, "SetCustomModel");
	
	    SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);   
        g_bApply[client] = false;
        
    }

}
stock SetAnimation(client, const String:Animation[PLATFORM_MAX_PATH], AnimationType, ClientCommandType)
{
	SetCommandFlags("mp_playanimation", GetCommandFlags("mp_playanimation") ^FCVAR_CHEAT);
	SetCommandFlags("mp_playgesture", GetCommandFlags("mp_playgesture") ^FCVAR_CHEAT);
	new String:Anim[PLATFORM_MAX_PATH];
	switch(AnimationType)
	{
		case 1:
		{
			Format(Anim, PLATFORM_MAX_PATH, "mp_playanimation %s", Animation);
		}
		case 2:
		{
			Format(Anim, PLATFORM_MAX_PATH, "mp_playgesture %s", Animation);
		}
	}
	switch(ClientCommandType)
	{
		case 1: 	ClientCommand(client, Anim);
		case 2: 	FakeClientCommand(client, Anim);
		case 3:	FakeClientCommandEx(client, Anim);
	}
}
stock TF2_GetNameOfClass(TFClassType:iClass, String:sName[], iMaxlen)
{
	switch (iClass)
	{
		case TFClass_Scout: Format(sName, iMaxlen, "scout");
		case TFClass_Soldier: Format(sName, iMaxlen, "soldier");
		case TFClass_Pyro: Format(sName, iMaxlen, "pyro");
		case TFClass_DemoMan: Format(sName, iMaxlen, "demo");
		case TFClass_Heavy: Format(sName, iMaxlen, "heavy");
		case TFClass_Engineer: Format(sName, iMaxlen, "engineer");
		case TFClass_Medic: Format(sName, iMaxlen, "medic");
		case TFClass_Sniper: Format(sName, iMaxlen, "sniper");
		case TFClass_Spy: Format(sName, iMaxlen, "spy");
	}
}
stock TF2_GetNameOfClassVo(TFClassType:iClass, String:sName[], iMaxlen)
{
	switch (iClass)
	{
		case TFClass_Scout: Format(sName, iMaxlen, "scout");
		case TFClass_Soldier: Format(sName, iMaxlen, "soldier");
		case TFClass_Pyro: Format(sName, iMaxlen, "pyro");
		case TFClass_DemoMan: Format(sName, iMaxlen, "demoman");
		case TFClass_Heavy: Format(sName, iMaxlen, "heavy");
		case TFClass_Engineer: Format(sName, iMaxlen, "engineer");
		case TFClass_Medic: Format(sName, iMaxlen, "medic");
		case TFClass_Sniper: Format(sName, iMaxlen, "sniper");
		case TFClass_Spy: Format(sName, iMaxlen, "spy");
	}
}

public Action:CritWeaponSH(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
    //SendConVarValue(entity, FindConVar("sv_cheats"), "0");
    //SendConVarValue(entity, sway, "1");
    //SendConVarValue(entity, interp, "0.1");
    int client = entity;
    if (IsValidClient(client)) {
        decl String:classname[35];
        TF2_GetNameOfClass(TF2_GetPlayerClass(client), classname, sizeof(classname));
        decl String:m_plrModelName[PLATFORM_MAX_PATH];
        GetEntPropString(entity, Prop_Data, "m_ModelName", m_plrModelName, sizeof(m_plrModelName));
        if (g_bIsHostile[client]) {
            SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", 0.8);
            return Plugin_Changed;
        }

				if (StrContains(sample, "vo/", false) != -1 && StrContains(sample, classname, false) != -1 && g_bIsHappy[entity]) {
					//PrintToServer(sample)

                    // Heavy
					if (StrContains(sample, "heavy_PainSevere01") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_PainSevere01", "heavy_LaughHappy01");
					}
					if (StrContains(sample, "heavy_PainSevere02") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_PainSevere02", "heavy_LaughHappy02");
					}
					if (StrContains(sample, "heavy_PainSevere03") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_PainSevere03", "heavy_LaughHappy03");
					}
					if (StrContains(sample, "heavy_PainSharp01") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_PainSharp01", "heavy_LaughShort01");
					}
					if (StrContains(sample, "heavy_PainSharp02") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_PainSharp02", "heavy_LaughShort02");
					}
					if (StrContains(sample, "heavy_PainSharp03") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_PainSharp03", "heavy_LaughShort03");
					}
					if (StrContains(sample, "heavy_PainSharp04") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_PainSharp04", "heavy_LaughShort01");
					}
					if (StrContains(sample, "heavy_PainSharp05") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_PainSharp05", "heavy_LaughShort02");
					}
					if (StrContains(sample, "heavy_PainCrticialDeath01") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_PainCrticialDeath01", "heavy_LaughLong01");
					}
					if (StrContains(sample, "heavy_PainCrticialDeath02") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_PainCrticialDeath02", "heavy_LaughLong02");
					}
					if (StrContains(sample, "heavy_PainCrticialDeath03") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_PainCrticialDeath03", "heavy_LaughLong02");
					}
					if (StrContains(sample, "heavy_AutoOnFire01") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_AutoOnFire01", "heavy_PositiveVocalization01");
					}
					if (StrContains(sample, "heavy_AutoOnFire02") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_AutoOnFire02", "heavy_PositiveVocalization02");
					}
					if (StrContains(sample, "heavy_AutoOnFire03") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_AutoOnFire03", "heavy_PositiveVocalization03");
					}
					if (StrContains(sample, "heavy_AutoOnFire04") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_AutoOnFire04", "heavy_PositiveVocalization04");
					}
					if (StrContains(sample, "heavy_AutoOnFire05") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_AutoOnFire05", "heavy_PositiveVocalization05");
					}
                    // Scout
                    
					if (StrContains(sample, "scout_PainSharp01") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_PainSharp01", "scout_LaughShort01");
					}
					if (StrContains(sample, "scout_PainSharp02") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_PainSharp02", "scout_LaughShort02");
					}
					if (StrContains(sample, "scout_PainSharp03") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_PainSharp03", "scout_LaughShort03");
					}
					if (StrContains(sample, "scout_PainSharp04") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_PainSharp04", "scout_LaughShort04");
					}
					if (StrContains(sample, "scout_PainSharp05") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_PainSharp05", "scout_LaughShort05");
					}
					if (StrContains(sample, "scout_PainSharp06") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_PainSharp06", "scout_LaughShort01");
					}
					if (StrContains(sample, "scout_PainSharp07") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_PainSharp07", "scout_LaughShort02");
					}
					if (StrContains(sample, "scout_PainSharp08") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_PainSharp08", "scout_LaughShort03");
					}
					if (StrContains(sample, "scout_AutoOnFire01") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_AutoOnFire01", "scout_PositiveVocalization02");
					}
					if (StrContains(sample, "scout_AutoOnFire02") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_AutoOnFire02", "scout_PositiveVocalization03");
					}
					if (StrContains(sample, "scout_PainSevere01") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_PainSevere01", "scout_LaughHappy01");
					}
					if (StrContains(sample, "scout_PainSevere02") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_PainSevere02", "scout_LaughHappy02");
					}
					if (StrContains(sample, "scout_PainSevere03") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_PainSevere03", "scout_LaughHappy03");
					}
					if (StrContains(sample, "scout_PainSevere04") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_PainSevere04", "scout_LaughHappy04");
					}
					if (StrContains(sample, "scout_PainSevere05") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_PainSevere05", "scout_LaughHappy01");
					}
					if (StrContains(sample, "scout_PainSevere06") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_PainSevere06", "scout_LaughHappy02");
					}
					if (StrContains(sample, "scout_PainCrticialDeath01") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_PainCrticialDeath01", "scout_LaughLong01");
					}
					if (StrContains(sample, "scout_PainCrticialDeath02") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_PainCrticialDeath02", "scout_LaughLong02");
					}
					if (StrContains(sample, "scout_PainCrticialDeath03") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_PainCrticialDeath03", "scout_LaughLong03");
					} 

                    // Robots

                    
                    // Heavy
					if (StrContains(sample, "heavy_mvm_PainSevere01") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_PainSevere01", "heavy_mvm_LaughHappy01");
					}
					if (StrContains(sample, "heavy_mvm_PainSevere02") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_PainSevere02", "heavy_mvm_LaughHappy02");
					}
					if (StrContains(sample, "heavy_mvm_PainSevere03") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_PainSevere03", "heavy_mvm_LaughHappy03");
					}
					if (StrContains(sample, "heavy_mvm_PainSharp01") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_PainSharp01", "heavy_mvm_LaughShort01");
					}
					if (StrContains(sample, "heavy_mvm_PainSharp02") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_PainSharp02", "heavy_mvm_LaughShort02");
					}
					if (StrContains(sample, "heavy_mvm_PainSharp03") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_PainSharp03", "heavy_mvm_LaughShort03");
					}
					if (StrContains(sample, "heavy_mvm_PainSharp04") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_PainSharp04", "heavy_mvm_LaughShort01");
					}
					if (StrContains(sample, "heavy_mvm_PainSharp05") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_PainSharp05", "heavy_mvm_LaughShort02");
					}
					if (StrContains(sample, "heavy_mvm_PainCrticialDeath01") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_PainCrticialDeath01", "heavy_mvm_LaughLong01");
					}
					if (StrContains(sample, "heavy_mvm_PainCrticialDeath02") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_PainCrticialDeath02", "heavy_mvm_LaughLong02");
					}
					if (StrContains(sample, "heavy_mvm_PainCrticialDeath03") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_PainCrticialDeath03", "heavy_mvm_LaughLong02");
					}
					if (StrContains(sample, "heavy_mvm_AutoOnFire01") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_AutoOnFire01", "heavy_mvm_PositiveVocalization01");
					}
					if (StrContains(sample, "heavy_mvm_AutoOnFire02") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_AutoOnFire02", "heavy_mvm_PositiveVocalization02");
					}
					if (StrContains(sample, "heavy_mvm_AutoOnFire03") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_AutoOnFire03", "heavy_mvm_PositiveVocalization03");
					}
					if (StrContains(sample, "heavy_mvm_AutoOnFire04") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_AutoOnFire04", "heavy_mvm_PositiveVocalization04");
					}
					if (StrContains(sample, "heavy_mvm_AutoOnFire05") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_AutoOnFire05", "heavy_mvm_PositiveVocalization05");
					}
                    // Scout
                    
					if (StrContains(sample, "scout_mvm_PainSharp01") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_PainSharp01", "scout_mvm_LaughShort01");
					}
					if (StrContains(sample, "scout_mvm_PainSharp02") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_PainSharp02", "scout_mvm_LaughShort02");
					}
					if (StrContains(sample, "scout_mvm_PainSharp03") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_PainSharp03", "scout_mvm_LaughShort03");
					}
					if (StrContains(sample, "scout_mvm_PainSharp04") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_PainSharp04", "scout_mvm_LaughShort04");
					}
					if (StrContains(sample, "scout_mvm_PainSharp05") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_PainSharp05", "scout_mvm_LaughShort05");
					}
					if (StrContains(sample, "scout_mvm_PainSharp06") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_PainSharp06", "scout_mvm_LaughShort01");
					}
					if (StrContains(sample, "scout_mvm_PainSharp07") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_PainSharp07", "scout_mvm_LaughShort02");
					}
					if (StrContains(sample, "scout_mvm_PainSharp08") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_PainSharp08", "scout_mvm_LaughShort03");
					}
					if (StrContains(sample, "scout_mvm_AutoOnFire01") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_AutoOnFire01", "scout_mvm_PositiveVocalization02");
					}
					if (StrContains(sample, "scout_mvm_AutoOnFire02") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_AutoOnFire02", "scout_mvm_PositiveVocalization03");
					}
					if (StrContains(sample, "scout_mvm_PainSevere01") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_PainSevere01", "scout_mvm_LaughHappy01");
					}
					if (StrContains(sample, "scout_mvm_PainSevere02") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_PainSevere02", "scout_mvm_LaughHappy02");
					}
					if (StrContains(sample, "scout_mvm_PainSevere03") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_PainSevere03", "scout_mvm_LaughHappy03");
					}
					if (StrContains(sample, "scout_mvm_PainSevere04") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_PainSevere04", "scout_mvm_LaughHappy04");
					}
					if (StrContains(sample, "scout_mvm_PainSevere05") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_PainSevere05", "scout_mvm_LaughHappy01");
					}
					if (StrContains(sample, "scout_mvm_PainSevere06") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_PainSevere06", "scout_mvm_LaughHappy02");
					}
					if (StrContains(sample, "scout_mvm_PainCrticialDeath01") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_PainCrticialDeath01", "scout_mvm_LaughLong01");
					}
					if (StrContains(sample, "scout_mvm_PainCrticialDeath02") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_PainCrticialDeath02", "scout_mvm_LaughLong02");
					}
					if (StrContains(sample, "scout_mvm_PainCrticialDeath03") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_PainCrticialDeath03", "scout_mvm_LaughLong03");
					} 

                    // Giant

                    
                    // Heavy
					if (StrContains(sample, "heavy_mvm_m_PainSevere01") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_m_PainSevere01", "heavy_mvm_m_LaughHappy01");
					}
					if (StrContains(sample, "heavy_mvm_m_PainSevere02") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_m_PainSevere02", "heavy_mvm_m_LaughHappy02");
					}
					if (StrContains(sample, "heavy_mvm_m_PainSevere03") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_m_PainSevere03", "heavy_mvm_m_LaughHappy03");
					}
					if (StrContains(sample, "heavy_mvm_m_PainSharp01") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_m_PainSharp01", "heavy_mvm_m_LaughShort01");
					}
					if (StrContains(sample, "heavy_mvm_m_PainSharp02") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_m_PainSharp02", "heavy_mvm_m_LaughShort02");
					}
					if (StrContains(sample, "heavy_mvm_m_PainSharp03") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_m_PainSharp03", "heavy_mvm_m_LaughShort03");
					}
					if (StrContains(sample, "heavy_mvm_m_PainSharp04") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_m_PainSharp04", "heavy_mvm_m_LaughShort01");
					}
					if (StrContains(sample, "heavy_mvm_m_PainSharp05") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_m_PainSharp05", "heavy_mvm_m_LaughShort02");
					}
					if (StrContains(sample, "heavy_mvm_m_PainCrticialDeath01") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_m_PainCrticialDeath01", "heavy_mvm_m_LaughLong01");
					}
					if (StrContains(sample, "heavy_mvm_m_PainCrticialDeath02") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_m_PainCrticialDeath02", "heavy_mvm_m_LaughLong02");
					}
					if (StrContains(sample, "heavy_mvm_m_PainCrticialDeath03") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_m_PainCrticialDeath03", "heavy_mvm_m_LaughLong02");
					}
					if (StrContains(sample, "heavy_mvm_m_AutoOnFire01") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_m_AutoOnFire01", "heavy_mvm_m_PositiveVocalization01");
					}
					if (StrContains(sample, "heavy_mvm_m_AutoOnFire02") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_m_AutoOnFire02", "heavy_mvm_m_PositiveVocalization02");
					}
					if (StrContains(sample, "heavy_mvm_m_AutoOnFire03") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_m_AutoOnFire03", "heavy_mvm_m_PositiveVocalization03");
					}
					if (StrContains(sample, "heavy_mvm_m_AutoOnFire04") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_m_AutoOnFire04", "heavy_mvm_m_PositiveVocalization04");
					}
					if (StrContains(sample, "heavy_mvm_m_AutoOnFire05") != -1) {
						ReplaceString(sample, sizeof(sample), "heavy_mvm_m_AutoOnFire05", "heavy_mvm_m_PositiveVocalization05");
					}
                    // Scout
                    
					if (StrContains(sample, "scout_mvm_m_PainSharp01") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_m_PainSharp01", "scout_mvm_m_LaughShort01");
					}
					if (StrContains(sample, "scout_mvm_m_PainSharp02") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_m_PainSharp02", "scout_mvm_m_LaughShort02");
					}
					if (StrContains(sample, "scout_mvm_m_PainSharp03") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_m_PainSharp03", "scout_mvm_m_LaughShort03");
					}
					if (StrContains(sample, "scout_mvm_m_PainSharp04") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_m_PainSharp04", "scout_mvm_m_LaughShort04");
					}
					if (StrContains(sample, "scout_mvm_m_PainSharp05") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_m_PainSharp05", "scout_mvm_m_LaughShort05");
					}
					if (StrContains(sample, "scout_mvm_m_PainSharp06") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_m_PainSharp06", "scout_mvm_m_LaughShort01");
					}
					if (StrContains(sample, "scout_mvm_m_PainSharp07") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_m_PainSharp07", "scout_mvm_m_LaughShort02");
					}
					if (StrContains(sample, "scout_mvm_m_PainSharp08") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_m_PainSharp08", "scout_mvm_m_LaughShort03");
					}
					if (StrContains(sample, "scout_mvm_m_AutoOnFire01") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_m_AutoOnFire01", "scout_mvm_m_PositiveVocalization02");
					}
					if (StrContains(sample, "scout_mvm_m_AutoOnFire02") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_m_AutoOnFire02", "scout_mvm_m_PositiveVocalization03");
					}
					if (StrContains(sample, "scout_mvm_m_PainSevere01") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_m_PainSevere01", "scout_mvm_m_LaughHappy01");
					}
					if (StrContains(sample, "scout_mvm_m_PainSevere02") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_m_PainSevere02", "scout_mvm_m_LaughHappy02");
					}
					if (StrContains(sample, "scout_mvm_m_PainSevere03") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_m_PainSevere03", "scout_mvm_m_LaughHappy03");
					}
					if (StrContains(sample, "scout_mvm_m_PainSevere04") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_m_PainSevere04", "scout_mvm_m_LaughHappy04");
					}
					if (StrContains(sample, "scout_mvm_m_PainSevere05") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_m_PainSevere05", "scout_mvm_m_LaughHappy01");
					}
					if (StrContains(sample, "scout_mvm_m_PainSevere06") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_m_PainSevere06", "scout_mvm_m_LaughHappy02");
					}
					if (StrContains(sample, "scout_mvm_m_PainCrticialDeath01") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_m_PainCrticialDeath01", "scout_mvm_m_LaughLong01");
					}
					if (StrContains(sample, "scout_mvm_m_PainCrticialDeath02") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_m_PainCrticialDeath02", "scout_mvm_m_LaughLong02");
					}
					if (StrContains(sample, "scout_mvm_m_PainCrticialDeath03") != -1) {
						ReplaceString(sample, sizeof(sample), "scout_mvm_m_PainCrticialDeath03", "scout_mvm_m_LaughLong03");
					} 
					PrintToServer(sample)
                    
                    if (StrContains(m_plrModelName,"/bot_") != -1 && StrContains(m_plrModelName,"boss") == -1) {
                        if (StrContains(sample, "mvm/norm", false) != -1) return Plugin_Continue;
                        ReplaceString(sample, sizeof(sample), "vo/", "vo/mvm/norm/", false);
                        if (StrContains(sample, "vo/", false) != -1)
                            ReplaceString(sample, sizeof(sample), ".wav", ".mp3", false);
                        new String:classname_mvm[15];
                        new TFClassType:plrClass = TF2_GetPlayerClass(client);
                        TF2_GetNameOfClassVo(plrClass, classname, sizeof(classname));
                        Format(classname_mvm, sizeof(classname_mvm), "%s_mvm", classname);
                        ReplaceString(sample, sizeof(sample), classname, classname_mvm, false);
                        PrecacheSound(sample);
                        EmitSoundToAll(sample,client,channel,level,flags,volume,pitch);
                    } else if (StrContains(m_plrModelName,"/bot_") != -1 && StrContains(m_plrModelName,"boss") != -1) {
                        if (StrContains(sample, "mvm/mght", false) != -1) return Plugin_Continue;
                        ReplaceString(sample, sizeof(sample), "vo/", "vo/mvm/mght/", false);
                        ReplaceString(sample, sizeof(sample), "_", "_m_", false);
                        if (StrContains(sample, "vo/", false) != -1)
                            ReplaceString(sample, sizeof(sample), ".wav", ".mp3", false);
                        new String:classname_mvm[15];
                        new TFClassType:plrClass = TF2_GetPlayerClass(client);
                        TF2_GetNameOfClassVo(plrClass, classname, sizeof(classname));
                        Format(classname_mvm, sizeof(classname_mvm), "%s_mvm", classname);
                        ReplaceString(sample, sizeof(sample), classname, classname_mvm, false);
                        PrecacheSound(sample);
                        EmitSoundToAll(sample,client,channel,level,flags,volume,pitch);
                    } else {
                        EmitSoundToAll(sample,entity,channel,level,flags,volume,pitch);
                    }
		            return Plugin_Changed;
				}
            
                
        if (StrContains(m_plrModelName,"/bot_") != -1 && StrContains(m_plrModelName,"boss") == -1 && StrContains(sample,"weapon",false) != -1 && StrContains(sample,"flame_thrower") != -1) {
            ReplaceString(sample, sizeof(sample), ")weapons/", "^mvm/giant_pyro/", false);
            ReplaceString(sample, sizeof(sample), "loop_crit", "loop", false);
            ReplaceString(sample, sizeof(sample), "flame_thrower_", "giant_pyro_flamethrower_", false);
            level = 100;
            PrecacheSound(sample);
            return Plugin_Changed;
        }
        
        if (StrContains(m_plrModelName,"/bot_") != -1 && StrContains(m_plrModelName,"boss") == -1) {
            if (StrContains(sample, "vo/", false) == -1)
                return Plugin_Continue;
            if (StrContains(sample, classname, false) == -1)
                return Plugin_Continue;
            if (StrContains(sample, "announcer", false) != -1)
                return Plugin_Continue;

            if (StrContains(sample, "mvm/norm", false) != -1) return Plugin_Continue;
                
            ReplaceString(sample, sizeof(sample), "vo/", "vo/mvm/norm/", false);
            if (StrContains(sample, "vo/", false) != -1)
                ReplaceString(sample, sizeof(sample), ".wav", ".mp3", false);
            new String:classname_mvm[15];
            new TFClassType:plrClass = TF2_GetPlayerClass(client);
            TF2_GetNameOfClassVo(plrClass, classname, sizeof(classname));
            Format(classname_mvm, sizeof(classname_mvm), "%s_mvm", classname);
            ReplaceString(sample, sizeof(sample), classname, classname_mvm, false);
            PrecacheSound(sample);
            EmitSoundToAll(sample,client,channel,level,flags,volume,pitch);
            return Plugin_Changed;
        }
        if (StrContains(m_plrModelName,"/bot_") != -1 && StrContains(m_plrModelName,"boss") != -1) {
            if (StrContains(sample, "vo/", false) == -1)
                return Plugin_Continue;
            if (StrContains(sample, classname, false) == -1)
                return Plugin_Continue;
            if (StrContains(sample, "announcer", false) != -1)
                return Plugin_Continue;

            if (StrContains(sample, "mvm/mght", false) != -1) return Plugin_Continue;
                
            ReplaceString(sample, sizeof(sample), "vo/", "vo/mvm/mght/", false);
            ReplaceString(sample, sizeof(sample), "_", "_m_", false);
            if (StrContains(sample, "vo/", false) != -1)
                ReplaceString(sample, sizeof(sample), ".wav", ".mp3", false);
            new String:classname_mvm[15];
            new TFClassType:plrClass = TF2_GetPlayerClass(client);
            TF2_GetNameOfClassVo(plrClass, classname, sizeof(classname));
            Format(classname_mvm, sizeof(classname_mvm), "%s_mvm", classname);
            ReplaceString(sample, sizeof(sample), classname, classname_mvm, false);
            PrecacheSound(sample);
            EmitSoundToAll(sample,client,channel,level,flags,volume,pitch);
            return Plugin_Changed;
        }
        if (GetClientTeam(entity) == _:TFTeam_Blue && StrContains(m_plrModelName,"/bot_") == -1) {
            if (StrContains(sample, "vo/", false) == -1)
                return Plugin_Continue;
            if (StrContains(sample, classname, false) == -1)
                return Plugin_Continue;
            if (StrContains(sample, "announcer", false) != -1)
                return Plugin_Continue;
                
            ReplaceString(sample, sizeof(sample), "vo/mvm/mght/", "vo/", false);
            ReplaceString(sample, sizeof(sample), "vo/mvm/norm/", "vo/", false);
            ReplaceString(sample, sizeof(sample), "_mvm_", "_", false);
            ReplaceString(sample, sizeof(sample), "_m_", "_", false);
            if (StrContains(sample, "vo/", false) != -1)
                ReplaceString(sample, sizeof(sample), ".wav", ".mp3", false);
            new String:classname_mvm[15];
            new TFClassType:plrClass = TF2_GetPlayerClass(client);
            TF2_GetNameOfClassVo(plrClass, classname, sizeof(classname));
            Format(classname_mvm, sizeof(classname_mvm), "%s", classname);
            ReplaceString(sample, sizeof(sample), classname, classname_mvm, false);
            PrecacheSound(sample);
            EmitSoundToAll(sample,client,channel,level,flags,volume,pitch);
            return Plugin_Changed;
        }
        new hClientWeapon = GetEntPropEnt(entity, Prop_Send, "m_hActiveWeapon");
        if (hClientWeapon != -1) {
         
            char clsname[256]; 
            GetEntityClassname(hClientWeapon,clsname,sizeof(clsname));
            int iItem = -1;
            bool isItemIn = false;
            new pBody = GetEntProp(entity, Prop_Send, "m_nBody");
            new weaponindex = GetEntProp(hClientWeapon, Prop_Send, "m_iItemDefinitionIndex");

            if (GetConVarInt(FindConVar("sv_client_predict")) == 0 || TF2_IsPlayerInCondition(client,TFCond_Disguised) != false) {
                if (StrContains(sample,"weapon",false) != -1 && StrContains(sample,"reload",false) == -1 && hClientWeapon != GetPlayerWeaponSlot(client, 2)) {

                    PrecacheSound(sample);
                    if (StrContains(sample,"weapon",false) != -1 && (StrContains(sample,"shoot",false) != -1 || StrContains(sample,"fire",false) != -1)) {
                        if (hClientWeapon == GetPlayerWeaponSlot(client, 0)) {
                            if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                                SetAnimation(client,"ACT_MP_ATTACK_SWIM_PRIMARY",2,3)
                            } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                                SetAnimation(client,"ACT_MP_ATTACK_CROUCH_PRIMARY",2,3)
                            } else {
                                SetAnimation(client,"ACT_MP_ATTACK_STAND_PRIMARY",2,3)
                            }
                        } else if (hClientWeapon == GetPlayerWeaponSlot(client, 1)) {
                            if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                                SetAnimation(client,"ACT_MP_ATTACK_SWIM_SECONDARY",2,3)
                            } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                                SetAnimation(client,"ACT_MP_ATTACK_CROUCH_SECONDARY",2,3)
                            } else {
                                SetAnimation(client,"ACT_MP_ATTACK_STAND_SECONDARY",2,3)
                            }
                        }
                    }
                    return Plugin_Changed;
                }
                if (StrContains(sample,"weapon",false) != -1 && (StrContains(sample,"hit",false) != -1)) {

                    PrecacheSound(sample);
                    EmitSoundToAll(sample,entity,channel,level,flags,volume,pitch);

                }
                if (StrContains(sample,"weapon",false) != -1 && (StrContains(sample,"boxing_gloves_hit",false) != -1)) {

                    if (g_bIsCrit[entity]) {

                        ReplaceString(sample, sizeof(sample), "boxing_gloves_hit1", "boxing_gloves_hit_crit1", false);
                        ReplaceString(sample, sizeof(sample), "boxing_gloves_hit2", "boxing_gloves_hit_crit2", false);
                        ReplaceString(sample, sizeof(sample), "boxing_gloves_hit3", "boxing_gloves_hit_crit3", false);
                        ReplaceString(sample, sizeof(sample), "boxing_gloves_hit4", "boxing_gloves_hit_crit1", false);
                        PrecacheSound(sample);
                        EmitSoundToAll(sample,entity,channel,level,flags,volume,pitch);

                        return Plugin_Changed;
                    }

                }
                if (StrContains(sample,"weapon",false) != -1 && (StrContains(sample,"swing",false) != -1 || StrContains(sample,"swing_crit",false) != -1 || StrContains(sample,"miss",false) != -1)) {

                    PrecacheSound(sample);
                    EmitSoundToAll(sample,entity,channel,level,flags,volume,pitch);
                    if (StrContains(sample,"swing_crit",false) != -1) {
                        
                        if (StrEqual(clsname,"tf_weapon_knife")) {
                            if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                                SetAnimation(client,"ACT_MP_ATTACK_CROUCH_MELEE_SECONDARY",2,3)
                            }
                        }
                    }
                    if (hClientWeapon == GetPlayerWeaponSlot(client, 2)) {
                            if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                                SetAnimation(client,"ACT_MP_ATTACK_SWIM_MELEE",2,3)
                            } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                                SetAnimation(client,"ACT_MP_ATTACK_CROUCH_MELEE",2,3)
                            } else {
                                SetAnimation(client,"ACT_MP_ATTACK_STAND_MELEE",2,3)
                            }
                    }
                        
                    return Plugin_Changed;
                }
            } else {
                
                if (StrContains(sample,"weapon",false) != -1 && StrContains(sample,"reload",false) == -1 && hClientWeapon != GetPlayerWeaponSlot(client, 2)) {

                    PrecacheSound(sample);
                    //EmitSoundToAll(sample,entity,channel,level,flags,volume,pitch);
                    return Plugin_Changed;
                }
                if (StrContains(sample,"weapon",false) != -1 && (StrContains(sample,"swing",false) != -1 || StrContains(sample,"miss",false) != -1)) {

                    PrecacheSound(sample);
                    EmitSoundToAll(sample,entity,channel,level,flags,volume,pitch);
                    return Plugin_Changed;
                }
            }
            if (StrContains(sample,"weapon",false) != -1 && StrContains(sample,"reload",false) != -1) {
                //SendConVarValue(entity, sv_cheats, "1");
                new ammo = GetEntProp(hClientWeapon, Prop_Send, "m_iClip1", 1);
                PrecacheSound(sample);
                if (GetConVarInt(FindConVar("sv_client_predict")) == 0) {
                    EmitSoundToAll(sample,entity,channel,level,flags,volume,pitch);
                }
                if (StrEqual(clsname,"tf_weapon_shotgun_soldier") || StrEqual(clsname,"tf_weapon_shotgun_hwg") || StrEqual(clsname,"tf_weapon_shotgun_pyro") ) {
                    if (!g_bReloading[client]) {
                        if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                            SetAnimation(client,"ACT_MP_RELOAD_SWIM_SECONDARY",2,3)
                        } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                            SetAnimation(client,"ACT_MP_RELOAD_CROUCH_SECONDARY",2,3)
                        } else {
                            SetAnimation(client,"ACT_MP_RELOAD_STAND_SECONDARY",2,3)
                        }
                        if (ammo == 5) {
                            CreateTimer(0.5, Timer_ReloadAnimDoneSecondary, entity, TIMER_DATA_HNDL_CLOSE);
                        }
                        g_bReloading[client] = true;
                    } else if (ammo == 5) {
                        if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                            SetAnimation(client,"ACT_MP_RELOAD_SWIM_SECONDARY_LOOP",2,3)
                        } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                            SetAnimation(client,"ACT_MP_RELOAD_CROUCH_SECONDARY_LOOP",2,3)
                        } else {
                            SetAnimation(client,"ACT_MP_RELOAD_STAND_SECONDARY_LOOP",2,3)
                        }
                        CreateTimer(0.5, Timer_ReloadAnimDoneSecondary, entity, TIMER_DATA_HNDL_CLOSE);
                    } else {
                        if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                            SetAnimation(client,"ACT_MP_RELOAD_SWIM_SECONDARY_LOOP",2,3)
                        } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                            SetAnimation(client,"ACT_MP_RELOAD_CROUCH_SECONDARY_LOOP",2,3)
                        } else {
                            SetAnimation(client,"ACT_MP_RELOAD_STAND_SECONDARY_LOOP",2,3)
                        }
                    }
                } 
                if (StrEqual(clsname,"tf_weapon_grenadelauncher") || StrEqual(clsname,"tf_weapon_cannon")) {
                    if (!g_bReloading[client]) {
                        if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                            SetAnimation(client,"ACT_MP_RELOAD_SWIM_SECONDARY",2,3)
                        } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                            SetAnimation(client,"ACT_MP_RELOAD_CROUCH_SECONDARY",2,3)
                        } else {
                            SetAnimation(client,"ACT_MP_RELOAD_STAND_SECONDARY",2,3)
                        }
                        if (ammo == 3) {
                            CreateTimer(0.6, Timer_ReloadAnimDoneSecondary, entity, TIMER_DATA_HNDL_CLOSE);
                        }
                        g_bReloading[client] = true;
                    } else if (ammo == 3) {
                        if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                            SetAnimation(client,"ACT_MP_RELOAD_SWIM_SECONDARY_LOOP",2,3)
                        } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                            SetAnimation(client,"ACT_MP_RELOAD_CROUCH_SECONDARY_LOOP",2,3)
                        } else {
                            SetAnimation(client,"ACT_MP_RELOAD_STAND_SECONDARY_LOOP",2,3)
                        }
                        CreateTimer(0.6, Timer_ReloadAnimDoneSecondary, entity, TIMER_DATA_HNDL_CLOSE);
                    } else {
                        if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                            SetAnimation(client,"ACT_MP_RELOAD_SWIM_SECONDARY_LOOP",2,3)
                        } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                            SetAnimation(client,"ACT_MP_RELOAD_CROUCH_SECONDARY_LOOP",2,3)
                        } else {
                            SetAnimation(client,"ACT_MP_RELOAD_STAND_SECONDARY_LOOP",2,3)
                        }
                    }
                } 
                if (StrEqual(clsname,"tf_weapon_scattergun")
                || StrEqual(clsname,"tf_weapon_shotgun_primary")) {
                    if (!g_bReloading[client]) {
                        if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                            SetAnimation(client,"ACT_MP_RELOAD_SWIM_PRIMARY",2,3)
                        } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                            SetAnimation(client,"ACT_MP_RELOAD_CROUCH_PRIMARY",2,3)
                        } else {
                            SetAnimation(client,"ACT_MP_RELOAD_STAND_PRIMARY",2,3)
                        }
                        if (ammo == 5) {
                            CreateTimer(0.5, Timer_ReloadAnimDonePrimary, entity, TIMER_DATA_HNDL_CLOSE);
                        }
                        g_bReloading[client] = true;
                    } else if (ammo == 5) {
                        if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                            SetAnimation(client,"ACT_MP_RELOAD_SWIM_PRIMARY_LOOP",2,3)
                        } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                            SetAnimation(client,"ACT_MP_RELOAD_CROUCH_PRIMARY_LOOP",2,3)
                        } else {
                            SetAnimation(client,"ACT_MP_RELOAD_STAND_PRIMARY_LOOP",2,3)
                        }
                        CreateTimer(0.5, Timer_ReloadAnimDonePrimary, entity, TIMER_DATA_HNDL_CLOSE);
                    } else {
                        if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                            SetAnimation(client,"ACT_MP_RELOAD_SWIM_PRIMARY_LOOP",2,3)
                        } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                            SetAnimation(client,"ACT_MP_RELOAD_CROUCH_PRIMARY_LOOP",2,3)
                        } else {
                            SetAnimation(client,"ACT_MP_RELOAD_STAND_PRIMARY_LOOP",2,3)
                        }
                    }
                }
                if (StrEqual(clsname,"tf_weapon_sentry_revenge")) {
                    if (!g_bReloading[client]) {
                        if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                            SetAnimation(client,"ACT_MP_RELOAD_SWIM_PRIMARY",2,3)
                        } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                            SetAnimation(client,"ACT_MP_RELOAD_CROUCH_PRIMARY",2,3)
                        } else {
                            SetAnimation(client,"ACT_MP_RELOAD_STAND_PRIMARY",2,3)
                        }
                        if (ammo == 2) {
                            CreateTimer(0.5, Timer_ReloadAnimDonePrimary, entity, TIMER_DATA_HNDL_CLOSE);
                        }
                        g_bReloading[client] = true;
                    } else if (ammo == 2) {
                        if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                            SetAnimation(client,"ACT_MP_RELOAD_SWIM_PRIMARY_LOOP",2,3)
                        } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                            SetAnimation(client,"ACT_MP_RELOAD_CROUCH_PRIMARY_LOOP",2,3)
                        } else {
                            SetAnimation(client,"ACT_MP_RELOAD_STAND_PRIMARY_LOOP",2,3)
                        }
                        CreateTimer(0.5, Timer_ReloadAnimDonePrimary, entity, TIMER_DATA_HNDL_CLOSE);
                    } else {
                        if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                            SetAnimation(client,"ACT_MP_RELOAD_SWIM_PRIMARY_LOOP",2,3)
                        } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                            SetAnimation(client,"ACT_MP_RELOAD_CROUCH_PRIMARY_LOOP",2,3)
                        } else {
                            SetAnimation(client,"ACT_MP_RELOAD_STAND_PRIMARY_LOOP",2,3)
                        }
                    }
                }
                if (StrEqual(clsname,"tf_weapon_pipebomblauncher")) {
                    if (!g_bReloading[client]) {
                        if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                            SetAnimation(client,"ACT_MP_RELOAD_SWIM_PRIMARY",2,3)
                        } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                            SetAnimation(client,"ACT_MP_RELOAD_CROUCH_PRIMARY",2,3)
                        } else {
                            SetAnimation(client,"ACT_MP_RELOAD_STAND_PRIMARY",2,3)
                        }
                        
                        if (ammo == 7) {
                            CreateTimer(0.6, Timer_ReloadAnimDonePrimary, entity, TIMER_DATA_HNDL_CLOSE);
                        }
                        g_bReloading[client] = true;
                    } else if (ammo == 7) {
                        if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                            SetAnimation(client,"ACT_MP_RELOAD_SWIM_PRIMARY_LOOP",2,3)
                        } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                            SetAnimation(client,"ACT_MP_RELOAD_CROUCH_PRIMARY_LOOP",2,3)
                        } else {
                            SetAnimation(client,"ACT_MP_RELOAD_STAND_PRIMARY_LOOP",2,3)
                        }
                        CreateTimer(0.5, Timer_ReloadAnimDonePrimary, entity, TIMER_DATA_HNDL_CLOSE);
                    } else {
                        if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                            SetAnimation(client,"ACT_MP_RELOAD_SWIM_PRIMARY_LOOP",2,3)
                        } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                            SetAnimation(client,"ACT_MP_RELOAD_CROUCH_PRIMARY_LOOP",2,3)
                        } else {
                            SetAnimation(client,"ACT_MP_RELOAD_STAND_PRIMARY_LOOP",2,3)
                        }
                    }
                }
                if (StrEqual(clsname,"tf_weapon_rocketlauncher") || StrEqual(clsname,"tf_weapon_rocketlauncher_directhit") || StrEqual(clsname,"tf_weapon_rocketlauncher_airstrike")) {
                    if (!g_bReloading[client]) {
                        if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                            SetAnimation(client,"ACT_MP_RELOAD_SWIM_PRIMARY",2,3)
                        } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                            SetAnimation(client,"ACT_MP_RELOAD_CROUCH_PRIMARY",2,3)
                        } else {
                            SetAnimation(client,"ACT_MP_RELOAD_STAND_PRIMARY",2,3)
                        }
                        if (ammo == 3) {
                            CreateTimer(0.8, Timer_ReloadAnimDonePrimary, entity, TIMER_DATA_HNDL_CLOSE);
                        }
                        g_bReloading[client] = true;
                    } else if (ammo == 3) {
                        if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                            SetAnimation(client,"ACT_MP_RELOAD_SWIM_PRIMARY_LOOP",2,3)
                        } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                            SetAnimation(client,"ACT_MP_RELOAD_CROUCH_PRIMARY_LOOP",2,3)
                        } else {
                            SetAnimation(client,"ACT_MP_RELOAD_STAND_PRIMARY_LOOP",2,3)
                        }
                        CreateTimer(0.8, Timer_ReloadAnimDonePrimary, entity, TIMER_DATA_HNDL_CLOSE);
                    } else {  
                        if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                            SetAnimation(client,"ACT_MP_RELOAD_SWIM_PRIMARY_LOOP",2,3)
                        } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                            SetAnimation(client,"ACT_MP_RELOAD_CROUCH_PRIMARY_LOOP",2,3)
                        } else {
                            SetAnimation(client,"ACT_MP_RELOAD_STAND_PRIMARY_LOOP",2,3)
                        }
                    }
                }
                if (StrEqual(clsname,"tf_weapon_particle_cannon")) {
                    if (!g_bReloading[client]) {
                        if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                            SetAnimation(client,"ACT_MP_RELOAD_SWIM_PRIMARY_ALT",2,3)
                        } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                            SetAnimation(client,"ACT_MP_RELOAD_CROUCH_PRIMARY_ALT",2,3)
                        } else {
                            SetAnimation(client,"ACT_MP_RELOAD_STAND_PRIMARY_ALT",2,3)
                        }
                        if (ammo == 3) {
                            CreateTimer(0.8, Timer_ReloadAnimDonePrimary2, entity, TIMER_DATA_HNDL_CLOSE);
                        }
                        g_bReloading[client] = true;
                    } else if (ammo == 3) {
                        if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                            SetAnimation(client,"ACT_MP_RELOAD_SWIM_PRIMARY_LOOP",2,3)
                        } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                            SetAnimation(client,"ACT_MP_RELOAD_CROUCH_PRIMARY_LOOP_ALT",2,3)
                        } else {
                            SetAnimation(client,"ACT_MP_RELOAD_STAND_PRIMARY_LOOP_ALT",2,3)
                        }
                        CreateTimer(0.8, Timer_ReloadAnimDonePrimary2, entity, TIMER_DATA_HNDL_CLOSE);
                    } else {  
                        if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                            SetAnimation(client,"ACT_MP_RELOAD_SWIM_PRIMARY_LOOP",2,3)
                        } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                            SetAnimation(client,"ACT_MP_RELOAD_CROUCH_PRIMARY_LOOP_ALT",2,3)
                        } else {
                            SetAnimation(client,"ACT_MP_RELOAD_STAND_PRIMARY_LOOP_ALT",2,3)
                        }
                    }
                }
                if (StrEqual(clsname,"tf_weapon_smg") 
                || StrEqual(clsname,"tf_weapon_pistol")
                || StrEqual(clsname,"tf_weapon_pistol_scout")
                || StrEqual(clsname,"tf_weapon_handgun_scout_primary")
                || StrEqual(clsname,"tf_weapon_revolver")) {
                    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                        SetAnimation(client,"ACT_MP_RELOAD_SWIM_SECONDARY",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_RELOAD_CROUCH_SECONDARY",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_RELOAD_STAND_SECONDARY",2,3)
                    }
                }
                
                if (StrEqual(clsname,"tf_weapon_compound_bow") || weaponindex == 45 || weaponindex == 448) {
                    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                        SetAnimation(client,"ACT_MP_RELOAD_SWIM_ITEM2",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_RELOAD_CROUCH_ITEM2",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_RELOAD_STAND_ITEM2",2,3)
                    }
                }
                if (StrEqual(clsname,"tf_weapon_syringegun_medic")||StrEqual(clsname,"tf_weapon_crossbow")) {
                    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                        SetAnimation(client,"ACT_MP_RELOAD_SWIM_PRIMARY",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_RELOAD_CROUCH_PRIMARY",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_RELOAD_STAND_PRIMARY",2,3)
                    }
                }
                return Plugin_Changed;
            }   
        }
        
    }
	return Plugin_Continue;
}
 
public Action Timer_ReloadAnimDonePrimary(Handle timer, int client)
{
    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
        SetAnimation(client,"ACT_MP_RELOAD_SWIM_PRIMARY_END",2,3)
    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
        SetAnimation(client,"ACT_MP_RELOAD_CROUCH_PRIMARY_END",2,3)
    } else {
        SetAnimation(client,"ACT_MP_RELOAD_STAND_PRIMARY_END",2,3)
    }
    
	//SendConVarValue(client, sv_cheats, "0");
    g_bReloading[client] = false;
    return Plugin_Continue;
}
public Action Timer_SetReady(Handle timer, int client)
{
	if (GetConVarInt(cvarForceHuman) == 1){
		if (IsFakeClient(client)) {
			
			char classname[256]; 
			TF2_GetNameOfClass(TF2_GetPlayerClass(client), classname, sizeof(classname));
			new String:Mdl[PLATFORM_MAX_PATH];
			Format(Mdl, sizeof(Mdl), "models/player/%s.mdl", classname, classname);
			ReplaceString(Mdl, sizeof(Mdl), "demoman", "demo", false);
			SetVariantString(Mdl);
			AcceptEntityInput(client, "SetCustomModel");
			SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1); 

		}
	}
    return Plugin_Continue;
}
public Action Timer_SetNotShot(Handle timer, int victim)
{
    if (g_bShotByImpostor[victim]) {
        g_bShotByImpostor[victim] = false;
    }
    return Plugin_Continue;
}
public Action Timer_ReloadAnimDonePrimary2(Handle timer, int client)
{
    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
        SetAnimation(client,"ACT_MP_RELOAD_SWIM_PRIMARY_END",2,3)
    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
        SetAnimation(client,"ACT_MP_RELOAD_CROUCH_PRIMARY_END_ALT",2,3)
    } else {
        SetAnimation(client,"ACT_MP_RELOAD_STAND_PRIMARY_END_ALT",2,3)
    }
    
	//SendConVarValue(client, sv_cheats, "0");
    g_bReloading[client] = false;
    return Plugin_Continue;
}
// CreateTimer(0.01, Timer_SetPlaybackRate, entity);
public Action Timer_SetPlaybackRate(Handle timer, int client)
{
	if (!IsClientInGame(client)) {
		return Plugin_Stop;
	}
		if (!IsFakeClient(client) && (GetClientTeam(client) == 1 || GetClientTeam(client) == 0 || GetClientTeam(client) == 4))  {
			new entflags = GetEntityFlags( client );
			SetEntityFlags( client, entflags|FL_FAKECLIENT );
			ChangeClientTeam( client, GetRandomInt(2,3) );
			SetEntityFlags( client, entflags&~FL_FAKECLIENT );
		}
    return Plugin_Continue;
}
public Action Timer_ReloadAnimDoneSecondary(Handle timer, int client)
{
    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
        SetAnimation(client,"ACT_MP_RELOAD_SWIM_SECONDARY_END",2,3)
    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
        SetAnimation(client,"ACT_MP_RELOAD_CROUCH_SECONDARY_END",2,3)
    } else {
        SetAnimation(client,"ACT_MP_RELOAD_STAND_SECONDARY_END",2,3)
    }
	//SendConVarValue(client, sv_cheats, "0");
    g_bReloading[client] = false;
    return Plugin_Continue;
}

stock bool:IsValidClient(iClient)
{
	if(iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return false;

	if(IsClientSourceTV(iClient) || IsClientReplay(iClient))
		return false;

	return true;
}
public OnEntityCreated(iEntity, const String:sEntClass[])
{
	SDKHook(iEntity, SDKHook_Spawn, OnProjectileCreated);
}

public OnProjectileCreated(iEntity)
{
    
}
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
    if (weapon != -1) {

        char clsname[256]; 
        GetEntityClassname(weapon,clsname,sizeof(clsname));
        int whoShotMe = -1;
        if (g_bIsHostile[attacker] && GetClientTeam(victim) == GetClientTeam(attacker)) {
            shotByWhatImpostor[victim] = attacker;
        }
        if (g_bIsHostile[attacker] && GetClientTeam(victim) == GetClientTeam(attacker)) {
            whoShotMe = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
            if (StrEqual(clsname,"tf_weapon_knife")) {
                g_bStabbedByImpostor[victim] = true;
                SetEntProp(weapon, Prop_Send, "m_bReadyToBackstab", true);
                damagetype = DMG_CLUB;
                damagetype |= DMG_CRIT;
                damagecustom = TF_CUSTOM_BACKSTAB;
            }
            if (!g_bShotByImpostor[victim]) {
                g_bShotByImpostor[victim] = true;
                CreateTimer(0.01, Timer_SetNotShot, victim, TIMER_DATA_HNDL_CLOSE);
            }
            return Plugin_Changed;
        }
        if (g_bIsHostile[victim] && GetClientTeam(attacker) == GetClientTeam(victim)) {
            whoShotMe = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity"); 
            SDKHooks_TakeDamage(victim,inflictor,victim,damage,damagetype,weapon,damageForce,damagePosition)
            if (!g_bShotByImpostor[victim]) {
                g_bShotByImpostor[victim] = true;
                CreateTimer(0.01, Timer_SetNotShot, victim, TIMER_DATA_HNDL_CLOSE);
            }
            return Plugin_Changed;
        } 
    }
}


/*                                                   */
/*-=-=-=-=-=-The commands that do commands-=-=-=-=-=-*/
/*                                                   */
public Action:Command_FriendlyFire(client, args)
{
	new String:target_name[MAX_TARGET_LENGTH];
    GetClientName(client, target_name,sizeof(target_name))
	g_bIsHostile[client] = !g_bIsHostile[client];
    TF2_RegeneratePlayer(client);
    ShowActivity2(client, "[SM] ", "Toggled being a impostor on %s.", target_name);
	return Plugin_Handled;
}                                                
public Action:Command_Happy(client, args)
{
	new String:target_name[MAX_TARGET_LENGTH];
    GetClientName(client, target_name,sizeof(target_name))
	g_bIsHappy[client] = !g_bIsHappy[client];
    ShowActivity2(client, "[SM] ", "Toggled being happy on %s.", target_name);
	return Plugin_Handled;
}                                                
public Action:Command_Human(client, args)
{
	decl String:arg1[32];
	if (args < 1)
	{
		arg1 = "@me";
	}
	else GetCmdArg(1, arg1, sizeof(arg1));
	if (!StrEqual(arg1, "@me") && !CheckCommandAccess(client, "sm_behhh_others", ADMFLAG_ROOT, true))
	{
		ReplyToCommand(client, "[SM] %t", "No Access");
		return Plugin_Handled;
	}
	/**
	 * target_name - stores the noun identifying the target(s)
	 * target_list - array to store clients
	 * target_count - variable to store number of clients
	 * tn_is_ml - stores whether the noun must be translated
	 */
	new String:target_name[MAX_TARGET_LENGTH];
	new target_list[MAXPLAYERS], target_count;
	new bool:tn_is_ml;
 
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE|(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0), /* Only allow alive players. If targetting self, allow self. */
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
/*		if (strcmp(arg1, "@me", false) == 0 && target_count == COMMAND_TARGET_IMMUNE)
		{
			target_list[0] = client;
			target_count = 1;
		}
		else*/
		/* This function replies to the admin with a failure message */
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	for (new i = 0; i < target_count; i++)
	{    
		char classname[256]; 
		TF2_GetNameOfClass(TF2_GetPlayerClass(target_list[i]), classname, sizeof(classname));
		new String:Mdl[PLATFORM_MAX_PATH];
		Format(Mdl, sizeof(Mdl), "models/player/%s.mdl", classname, classname);
		ReplaceString(Mdl, sizeof(Mdl), "demoman", "demo", false);
		SetVariantString(Mdl);
		AcceptEntityInput(target_list[i], "SetCustomModel");
		SetEntProp(target_list[i], Prop_Send, "m_bUseClassAnimations", 1); 
		LogAction(client, target_list[i], "\"%L\" made \"%L\" a Human", client, target_list[i]);
	}
}                                            
public Action:Command_JoinBlue(client, args)
{
	new entflags = GetEntityFlags( client );
	SetEntityFlags( client, entflags|FL_FAKECLIENT );
	ChangeClientTeam( client, _:TFTeam_Blue );
	SetEntityFlags( client, entflags&~FL_FAKECLIENT );
    ShowClassPanel(client);
	return Plugin_Handled;
}                                         
public Action:Command_JoinRed(client, args)
{
	new entflags = GetEntityFlags( client );
	SetEntityFlags( client, entflags|FL_FAKECLIENT );
	ChangeClientTeam( client, _:TFTeam_Red );
	SetEntityFlags( client, entflags&~FL_FAKECLIENT );
    ShowClassPanel(client);
	return Plugin_Handled;
}

stock ShowClassPanel( iClient )
{
	if( !IsValidClient(iClient) || IsFakeClient(iClient) )
		return;
	
	ShowVGUIPanel( iClient, GetClientTeam(iClient) == _:TFTeam_Red ? "class_red" : "class_blue" );
}
public Action:TF2_CalcIsAttackCritical(client, weapon, String:weaponname[], &bool:result)
{
	new weaponindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
    new hClientWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    char clsname[256]; 
    GetEntityClassname(hClientWeapon,clsname,sizeof(clsname))
    if (g_bIsHostile[client] && StrEqual(clsname,"tf_weapon_knife")) {
        result = true;
        g_bIsCrit[client] = true;
        return Plugin_Handled;    
    }
    if (!StrEqual(clsname,"tf_weapon_knife") && !StrEqual(clsname,"tf_weapon_sniperrifle") && !StrEqual(clsname,"tf_weapon_flamethrower") && !StrEqual(clsname,"tf_weapon_smg") && !StrEqual(clsname,"tf_weapon_pistol") && !StrEqual(clsname,"tf_weapon_pistol_scout") && !StrEqual(clsname,"tf_weapon_syringegun_medic") && !StrEqual(clsname,"tf_weapon_minigun") && hClientWeapon != GetPlayerWeaponSlot(client, 2)) {
        if (!TF2Attrib_GetByName(hClientWeapon, "crit mod disabled")) {
            if (GetRandomInt(1,8) == 1) { 
                if (StrEqual(clsname,"tf_weapon_rocketlauncher") || StrEqual(clsname,"tf_weapon_rocketlauncher_directhit")) {
                    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_PRIMARY_ALT",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_ATTACK_CROUCH_PRIMARY_ALT",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_ATTACK_STAND_PRIMARY_ALT",2,3)
                    }
                }
                if (StrEqual(clsname,"tf_weapon_shotgun_soldier")) {
                    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_PRIMARY_ALT",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_ATTACK_CROUCH_PRIMARY_ALT",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_ATTACK_STAND_PRIMARY_ALT",2,3)
                    }
                }
                if (StrEqual(clsname,"tf_weapon_shotgun_hwg")) {
                    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_SECONDARY",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_SECONDARY",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_SECONDARY",2,3)
                    }
                }
                if (StrEqual(clsname,"tf_weapon_shotgun_pyro")) {
                    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_SECONDARY",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_SECONDARY",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_SECONDARY",2,3)
                    }
                }
                if (StrEqual(clsname,"tf_weapon_scattergun")) {
                    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_PRIMARY",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_PRIMARY",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_PRIMARY",2,3)
                    }
                }
                if (StrEqual(clsname,"tf_weapon_shotgun_primary")) {
                    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_PRIMARY",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_PRIMARY",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_PRIMARY",2,3)
                    }
                }
                result = true;
                g_bIsCrit[client] = true;
                return Plugin_Handled;     
            }
        }
    }
    if (hClientWeapon == GetPlayerWeaponSlot(client, 2) && (weaponindex == 264 || weaponindex == 1013)) {
             if (GetRandomInt(1,2) == 1) { 
                if (StrEqual(clsname,"tf_weapon_fists")) {
                    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                        SetAnimation(client,"ACT_MP_ATTACK_CROUCH_MELEE_SECONDARY",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_ATTACK_CROUCH_MELEE_SECONDARY",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_ATTACK_STAND_MELEE_SECONDARY",2,3)
                    }
                }
                if (StrEqual(clsname,"tf_weapon_knife")) {
                    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                        SetAnimation(client,"ACT_MP_ATTACK_CROUCH_MELEE_SECONDARY",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_ATTACK_CROUCH_MELEE_SECONDARY",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_ATTACK_STAND_MELEE_SECONDARY",2,3)
                    }
                }
                if (StrEqual(clsname,"tf_weapon_sword")) {
                    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_ITEM1",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_ITEM1",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_ITEM1",2,3)
                    }
                }
                if (StrEqual(clsname,"tf_weapon_bottle") || StrEqual(clsname,"tf_weapon_club") || StrEqual(clsname,"tf_weapon_shovel") || StrEqual(clsname,"tf_weapon_fireaxe") || StrEqual(clsname,"tf_weapon_breakable_sign")) {
                    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                        SetAnimation(client,"ACT_MP_THROW",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_THROW",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_THROW",2,3)
                    }
                }
                if (StrEqual(clsname,"tf_weapon_bonesaw")) {
                    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_MELEE",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_MELEE",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_MELEE",2,3)
                    }
                }
                if (StrEqual(clsname,"tf_weapon_robot_arm")) {
                    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_HARD_ITEM2",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_ATTACK_CROUCH_HARD_ITEM2",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_ATTACK_STAND_HARD_ITEM2",2,3)
                    }
                }
                result = true;
                g_bIsCrit[client] = true;
                return Plugin_Handled;    
            }
    }
                g_bIsCrit[client] = result;
    if (!StrEqual(clsname,"tf_weapon_knife") && hClientWeapon == GetPlayerWeaponSlot(client, 2)) {
        if (!TF2Attrib_GetByName(hClientWeapon, "crit mod disabled")) {
            if (GetRandomInt(1,6) == 1) { 
                if (StrEqual(clsname,"tf_weapon_fists")) {
                    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                        SetAnimation(client,"ACT_MP_ATTACK_CROUCH_MELEE_SECONDARY",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_ATTACK_CROUCH_MELEE_SECONDARY",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_ATTACK_STAND_MELEE_SECONDARY",2,3)
                    }
                }
                if (StrEqual(clsname,"tf_weapon_sword")) {
                    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_ITEM1",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_ITEM1",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_ITEM1",2,3)
                    }
                }
                if (StrEqual(clsname,"tf_weapon_bottle") || StrEqual(clsname,"tf_weapon_club") || StrEqual(clsname,"tf_weapon_shovel") || StrEqual(clsname,"tf_weapon_fireaxe") || StrEqual(clsname,"tf_weapon_breakable_sign")) {
                    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                        SetAnimation(client,"ACT_MP_THROW",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_THROW",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_THROW",2,3)
                    }
                }
                if (StrEqual(clsname,"tf_weapon_bonesaw")) {
                    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_MELEE",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_MELEE",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_MELEE",2,3)
                    }
                }
                if (StrEqual(clsname,"tf_weapon_robot_arm")) {
                    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_HARD_ITEM2",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_ATTACK_CROUCH_HARD_ITEM2",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_ATTACK_STAND_HARD_ITEM2",2,3)
                    }
                }
                result = true;
                g_bIsCrit[client] = true;
                return Plugin_Handled;  
            }
        }
    }

	return Plugin_Continue;
}

// stolen code


public OnGateCapture(const String:output[], caller, activator, Float:delay)
{
		new TeleporterExit = -1;
		while((TeleporterExit = FindEntityByClassname(TeleporterExit,"obj_teleporter")) != -1)
		{
			if(GetEntProp(TeleporterExit, Prop_Send, "m_iTeamNum") == _:TFTeam_Blue)
			{
				SDKHooks_TakeDamage(TeleporterExit, 0, 0, 500.0, DMG_CRUSH);
				//AcceptEntityInput( TeleporterExit, "Kill" ); kill teles on gate capture
			}
		}
			for (new i = 1; i <= MaxClients; i++)
			{
			if (IsClientInGame(i) && GetClientTeam(i) == _:TFTeam_Blue && !IsFakeClient(i))
			{
				new hat = -1;
				while((hat=FindEntityByClassname(hat, "tf_wearable"))!=INVALID_ENT_REFERENCE)
				{
					if(GetEntPropEnt(hat, Prop_Send, "m_hOwnerEntity") == i)
					{																																																																																																																																																							
						if(GetEntProp(hat, Prop_Send, "m_iItemDefinitionIndex") == 1057 || GetEntProp(hat, Prop_Send, "m_iItemDefinitionIndex") == 1063 || GetEntProp(hat, Prop_Send, "m_iItemDefinitionIndex") == 1062 || GetEntProp(hat, Prop_Send, "m_iItemDefinitionIndex") == 1065 || GetEntProp(hat, Prop_Send, "m_iItemDefinitionIndex") == 1058 ||GetEntProp(hat, Prop_Send, "m_iItemDefinitionIndex") == 1059 || GetEntProp(hat, Prop_Send, "m_iItemDefinitionIndex") == 1061 || GetEntProp(hat, Prop_Send, "m_iItemDefinitionIndex") == 1064 || GetEntProp(hat, Prop_Send, "m_iItemDefinitionIndex") == 1060)
						{										
							AcceptEntityInput(hat, "Kill");
						}
					}
				}
				SetEntProp(i, Prop_Send, "m_iTeamNum", 0);
				CreateTimer(0.13,ResetTeam, i);//prevent the crash
//				CreateTimer(0.1,Timer_TurnOffGateBotHat,i);
			}
			}
			new i3 = -1;
			while ((i3 = FindEntityByClassname(i3, "trigger_multiple")) != -1)
			{
				if(IsValidEntity(i3))
				{
				decl String:strName[50];
				GetEntPropString(i3, Prop_Data, "m_iName", strName, sizeof(strName));
				if(strcmp(strName, "gate2_door_alarm") == 0)
				{
					AcceptEntityInput(i3, "Disable");
					break;
				}
				}
			}
}

public Action:ResetTeam(Handle:timer,any:iclient)
{
	new entflags = GetEntityFlags(iclient);

	SetEntityFlags(iclient, entflags | FL_FAKECLIENT);
	SetEntProp(iclient, Prop_Send, "m_iTeamNum", 3);
	SetEntityFlags(iclient, entflags);
}