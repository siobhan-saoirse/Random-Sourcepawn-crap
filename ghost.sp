
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PZ			0
#define SMOKER		1
#define BOOMER		2
#define HUNTER		3
#define SPITTER		4
#define JOCKEY		5
#define CHARGER		6
#define WITCH		7
#define TANK			8
new Handle:g_hSetClass		= INVALID_HANDLE;
new Handle:g_hCreateAbility	= INVALID_HANDLE;
new Handle:g_hGameConf		= INVALID_HANDLE;
new g_oAbility			= 0;
new bool:g_bIsInfected[MAXPLAYERS + 1] = { false, ... };

public OnPluginStart()
{
	Sub_HookGameData("l4d2_zcs");
	LoadTranslations("common.phrases");
	RegAdminCmd("sm_pz", Command_PlayerZombie, ADMFLAG_ROOT, "It's a good time to infect - turns <target> into a Zombie"); 
	RegAdminCmd("sm_boomer", Command_Boomer, ADMFLAG_ROOT, "It's a good time to infect - turns <target> into a Boomer"); 
	RegAdminCmd("sm_hunter", Command_Hunter, ADMFLAG_ROOT, "It's a good time to infect - turns <target> into a Hunter"); 
	RegAdminCmd("sm_smoker", Command_Smoker, ADMFLAG_ROOT, "It's a good time to infect - turns <target> into a Smoker"); 
	RegAdminCmd("sm_tank", Command_Tank, ADMFLAG_ROOT, "It's a good time to infect - turns <target> into a Tank"); 
	RegAdminCmd("sm_charger", Command_Charger, ADMFLAG_ROOT, "It's a good time to infect - turns <target> into a Charger"); 
	RegAdminCmd("sm_spitter", Command_Spitter, ADMFLAG_ROOT, "It's a good time to infect - turns <target> into a Spitter"); 
	RegAdminCmd("sm_jockey", Command_Jockey, ADMFLAG_ROOT, "It's a good time to infect - turns <target> into a Jockey"); 
	RegAdminCmd("sm_boomerb", bCommand_Boomer, ADMFLAG_ROOT, "It's a good time to infect - turns <target> into a Boomer"); 
	RegAdminCmd("sm_hunterb", bCommand_Hunter, ADMFLAG_ROOT, "It's a good time to infect - turns <target> into a Hunter"); 
	RegAdminCmd("sm_smokerb", bCommand_Smoker, ADMFLAG_ROOT, "It's a good time to infect - turns <target> into a Smoker"); 
	RegAdminCmd("sm_tankb", bCommand_Tank, ADMFLAG_ROOT, "It's a good time to infect - turns <target> into a Tank"); 
	RegAdminCmd("sm_chargerb", bCommand_Charger, ADMFLAG_ROOT, "It's a good time to infect - turns <target> into a Charger"); 
	RegAdminCmd("sm_spitterb", bCommand_Spitter, ADMFLAG_ROOT, "It's a good time to infect - turns <target> into a Spitter"); 
	RegAdminCmd("sm_jockeyb", bCommand_Jockey, ADMFLAG_ROOT, "It's a good time to infect - turns <target> into a Jockey"); 
	RegAdminCmd("sm_ghost", Command_Ghost, ADMFLAG_ROOT, "It's a good time to spawn - turns <target> into a Ghost"); 
	RegAdminCmd("sm_unghost", Command_UnGhost, ADMFLAG_ROOT, "It's a good time to come back - turns <target> visible.");
	RegAdminCmd("sm_incap", Command_Infect, ADMFLAG_ROOT, "It's a good time to spawn - turns <target> into a Infected"); 
	RegAdminCmd("sm_uncap", Command_Unfect, ADMFLAG_ROOT, "It's a good time to spawn - turns <target> into a Infected"); 
    /*
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsClientReplay(i) && !IsClientSourceTV(i))
        {
            
	        SendProxy_Hook(i, "m_iTeamNum", Prop_Int, TeamProxyClient);
        }
    }*/
}

public OnClientPutInServer(client)
{
	OnClientDisconnect_Post(client);
}
public OnClientDisconnect_Post(client)
{
	g_bIsInfected[client] = false;
}

public Action:TeamProxyClient(entity, const String:propName[], &iValue, element)
{
	//PrintToServer("[debug] Action:MiniBossProxy(%d, '%s', %d)",
	//	entity,
	//	propName,
	//	iValue);
    
    decl String:m_plrModelName[PLATFORM_MAX_PATH];
    GetEntPropString(entity, Prop_Data, "m_ModelName", m_plrModelName, sizeof(m_plrModelName));
    
	if (g_bIsInfected[entity])
	{
        iValue = 2;
    } else {
        
	    new team = GetEntProp(entity, Prop_Send, "m_iTeamNum");
	    iValue = team;   

    }
	return Plugin_Changed;
}


public Sub_HookGameData(String:GameDataFile[])
{
	g_hGameConf = LoadGameConfigFile(GameDataFile);

	if (g_hGameConf != INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "SetClass");
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		g_hSetClass = EndPrepSDKCall();

		if (g_hSetClass == INVALID_HANDLE)
			SetFailState("[+] S_HGD: Error: Unable to find SetClass signature.");

		StartPrepSDKCall(SDKCall_Static);
		PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "CreateAbility");
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
		g_hCreateAbility = EndPrepSDKCall();

		if (g_hCreateAbility == INVALID_HANDLE)
			SetFailState("[+] S_HGD: Error: Unable to find CreateAbility signature.");

		g_oAbility = GameConfGetOffset(g_hGameConf, "oAbility");

		CloseHandle(g_hGameConf);
	}

	else
		SetFailState("[+] S_HGD: Error: Unable to load gamedata file, exiting.");
}

public Action:Command_PlayerZombie(client, args)
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
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0), /* Only allow alive players. If targetting self, allow self. */
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
		SetEntProp(target_list[i], Prop_Send, "m_zombieClass", PZ);
		LogAction(client, target_list[i], "\"%L\" made \"%L\" a PlayerZombie", client, target_list[i]);
	}
	return Plugin_Handled;
}
public Action:Command_Boomer(client, args)
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
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0), /* Only allow alive players. If targetting self, allow self. */
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
		SetEntProp(target_list[i], Prop_Send, "m_zombieClass", BOOMER);
		LogAction(client, target_list[i], "\"%L\" made \"%L\" a Boomer", client, target_list[i]);
	}
	return Plugin_Handled;
}
public Action:Command_Smoker(client, args)
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
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0), /* Only allow alive players. If targetting self, allow self. */
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
		SetEntProp(target_list[i], Prop_Send, "m_zombieClass", SMOKER);
		LogAction(client, target_list[i], "\"%L\" made \"%L\" a Smoker", client, target_list[i]);
	}
	return Plugin_Handled;
}
public Action:Command_Tank(client, args)
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
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0), /* Only allow alive players. If targetting self, allow self. */
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
		SetEntProp(target_list[i], Prop_Send, "m_zombieClass", TANK);
		LogAction(client, target_list[i], "\"%L\" made \"%L\" a Tank", client, target_list[i]);
	}
	return Plugin_Handled;
}
public Action:Command_Hunter(client, args)
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
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0), /* Only allow alive players. If targetting self, allow self. */
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
		SetEntProp(target_list[i], Prop_Send, "m_zombieClass", HUNTER);
		LogAction(client, target_list[i], "\"%L\" made \"%L\" a Hunter", client, target_list[i]);
	}
	return Plugin_Handled;
}
public Action:Command_Charger(client, args)
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
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0), /* Only allow alive players. If targetting self, allow self. */
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
		SetEntProp(target_list[i], Prop_Send, "m_zombieClass", CHARGER);
		LogAction(client, target_list[i], "\"%L\" made \"%L\" a Charger", client, target_list[i]);
	}
	return Plugin_Handled;
}
public Action:Command_Spitter(client, args)
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
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0), /* Only allow alive players. If targetting self, allow self. */
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
		SetEntProp(target_list[i], Prop_Send, "m_zombieClass", SPITTER);
		LogAction(client, target_list[i], "\"%L\" made \"%L\" a Spitter", client, target_list[i]);
	}
	return Plugin_Handled;
}
public Action:Command_Jockey(client, args)
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
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0), /* Only allow alive players. If targetting self, allow self. */
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
		SetEntProp(target_list[i], Prop_Send, "m_zombieClass", JOCKEY);
		LogAction(client, target_list[i], "\"%L\" made \"%L\" a Jockey", client, target_list[i]);
	}
	return Plugin_Handled;
}

// secondary


public Action:bCommand_PlayerZombie(client, args)
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
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0), /* Only allow alive players. If targetting self, allow self. */
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
		SetEntProp(target_list[i], Prop_Send, "m_zombieClass", PZ);
		AcceptEntityInput(MakeCompatEntRef(GetEntProp(target_list[i], Prop_Send, "m_customAbility")), "Kill");
		SetEntProp(target_list[i], Prop_Send, "m_customAbility", GetEntData(SDKCall(g_hCreateAbility, target_list[i]), g_oAbility));
		LogAction(client, target_list[i], "\"%L\" made \"%L\" a PlayerZombie", client, target_list[i]);
	}
	return Plugin_Handled;
}
public Action:bCommand_Boomer(client, args)
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
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0), /* Only allow alive players. If targetting self, allow self. */
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
		SetEntProp(target_list[i], Prop_Send, "m_zombieClass", BOOMER);
		AcceptEntityInput(MakeCompatEntRef(GetEntProp(target_list[i], Prop_Send, "m_customAbility")), "Kill");
		SetEntProp(target_list[i], Prop_Send, "m_customAbility", GetEntData(SDKCall(g_hCreateAbility, target_list[i]), g_oAbility));
		LogAction(client, target_list[i], "\"%L\" made \"%L\" a Boomer", client, target_list[i]);
	}
	return Plugin_Handled;
}
public Action:bCommand_Smoker(client, args)
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
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0), /* Only allow alive players. If targetting self, allow self. */
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
		SetEntProp(target_list[i], Prop_Send, "m_zombieClass", SMOKER);
		AcceptEntityInput(MakeCompatEntRef(GetEntProp(target_list[i], Prop_Send, "m_customAbility")), "Kill");
		SetEntProp(target_list[i], Prop_Send, "m_customAbility", GetEntData(SDKCall(g_hCreateAbility, target_list[i]), g_oAbility));
		LogAction(client, target_list[i], "\"%L\" made \"%L\" a Smoker", client, target_list[i]);
	}
	return Plugin_Handled;
}
public Action:bCommand_Tank(client, args)
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
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0), /* Only allow alive players. If targetting self, allow self. */
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
		SetEntProp(target_list[i], Prop_Send, "m_zombieClass", TANK);
		AcceptEntityInput(MakeCompatEntRef(GetEntProp(target_list[i], Prop_Send, "m_customAbility")), "Kill");
		SetEntProp(target_list[i], Prop_Send, "m_customAbility", GetEntData(SDKCall(g_hCreateAbility, target_list[i]), g_oAbility));
		LogAction(client, target_list[i], "\"%L\" made \"%L\" a Tank", client, target_list[i]);
	}
	return Plugin_Handled;
}
public Action:bCommand_Hunter(client, args)
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
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0), /* Only allow alive players. If targetting self, allow self. */
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
		SetEntProp(target_list[i], Prop_Send, "m_zombieClass", HUNTER);
		AcceptEntityInput(MakeCompatEntRef(GetEntProp(target_list[i], Prop_Send, "m_customAbility")), "Kill");
		SetEntProp(target_list[i], Prop_Send, "m_customAbility", GetEntData(SDKCall(g_hCreateAbility, target_list[i]), g_oAbility));
		LogAction(client, target_list[i], "\"%L\" made \"%L\" a Hunter", client, target_list[i]);
	}
	return Plugin_Handled;
}
public Action:bCommand_Charger(client, args)
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
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0), /* Only allow alive players. If targetting self, allow self. */
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
		SetEntProp(target_list[i], Prop_Send, "m_zombieClass", CHARGER);
		AcceptEntityInput(MakeCompatEntRef(GetEntProp(target_list[i], Prop_Send, "m_customAbility")), "Kill");
		SetEntProp(target_list[i], Prop_Send, "m_customAbility", GetEntData(SDKCall(g_hCreateAbility, target_list[i]), g_oAbility));
		LogAction(client, target_list[i], "\"%L\" made \"%L\" a Charger", client, target_list[i]);
	}
	return Plugin_Handled;
}
public Action:bCommand_Spitter(client, args)
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
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0), /* Only allow alive players. If targetting self, allow self. */
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
		SetEntProp(target_list[i], Prop_Send, "m_zombieClass", SPITTER);
		AcceptEntityInput(MakeCompatEntRef(GetEntProp(target_list[i], Prop_Send, "m_customAbility")), "Kill");
		SetEntProp(target_list[i], Prop_Send, "m_customAbility", GetEntData(SDKCall(g_hCreateAbility, target_list[i]), g_oAbility));
		LogAction(client, target_list[i], "\"%L\" made \"%L\" a Spitter", client, target_list[i]);
	}
	return Plugin_Handled;
}
public Action:bCommand_Jockey(client, args)
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
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0), /* Only allow alive players. If targetting self, allow self. */
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
		SetEntProp(target_list[i], Prop_Send, "m_zombieClass", JOCKEY);
		AcceptEntityInput(MakeCompatEntRef(GetEntProp(target_list[i], Prop_Send, "m_customAbility")), "Kill");
		SetEntProp(target_list[i], Prop_Send, "m_customAbility", GetEntData(SDKCall(g_hCreateAbility, target_list[i]), g_oAbility));
		LogAction(client, target_list[i], "\"%L\" made \"%L\" a Jockey", client, target_list[i]);
	}
	return Plugin_Handled;
}

public Action:Command_Ghost(client, args)
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
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0), /* Only allow alive players. If targetting self, allow self. */
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
        
		SetEntProp(target_list[i], Prop_Send, "m_isGhost", 1);
		SetEntProp(target_list[i], Prop_Send, "m_usSolidFlags", 16);
		SetEntProp(target_list[i], Prop_Send, "movetype", 2);
		SetEntProp(target_list[i], Prop_Send, "deadflag", 0);
		SetEntProp(target_list[i], Prop_Send, "m_lifeState", 0);
		//SetEntProp(bot, Prop_Send, "m_fFlags", 129);
		SetEntProp(target_list[i], Prop_Send, "m_iObserverMode", 0);
		SetEntProp(target_list[i], Prop_Send, "m_iPlayerState", 0);
		SetEntProp(target_list[i], Prop_Send, "m_zombieState", 2);
		LogAction(client, target_list[i], "\"%L\" made \"%L\" a Ghost", client, target_list[i]);
	}
	return Plugin_Handled;
}

public Action:Command_UnGhost(client, args)
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
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0), /* Only allow alive players. If targetting self, allow self. */
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
		SetEntProp(target_list[i], Prop_Send, "m_isGhost", 0);
		LogAction(client, target_list[i], "\"%L\" made \"%L\" a Ghost", client, target_list[i]);
	}
	return Plugin_Handled;
}


public Action:Command_Infect(client, args)
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
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0), /* Only allow alive players. If targetting self, allow self. */
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
		SetEntProp(target_list[i], Prop_Send, "m_isIncapacitated", 1);
		LogAction(client, target_list[i], "\"%L\" made \"%L\" incapacitated", client, target_list[i]);
	}
	return Plugin_Handled;
}

public Action:Command_Unfect(client, args)
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
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0), /* Only allow alive players. If targetting self, allow self. */
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
		SetEntProp(target_list[i], Prop_Send, "m_isIncapacitated", 0);
		LogAction(client, target_list[i], "\"%L\" made \"%L\" revived", client, target_list[i]);
	}
	return Plugin_Handled;
}