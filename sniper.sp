#include <sdktools>
#include <tf2_stocks>
#include <tf2attributes>

#pragma newdecls required

enum MissionType
{
	NOMISSION         = 0,
	UNKNOWN           = 1,
	DESTROY_SENTRIES  = 2,
	SNIPER            = 3,
	SPY               = 4,
	ENGINEER          = 5,
	REPROGRAMMED      = 6,
};

public Plugin myinfo = 
{
	name = "[TF2] Buster",
	author = "Pelipoika",
	description = "!",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

int g_iOffsetSBTarget;

Handle g_hSetMission;

bool g_bIsBuster[MAXPLAYERS + 1];

public void OnPluginStart()
{
//	RegAdminCmd("sm_bust", Command_Bust, ADMFLAG_ROOT, "Send a sentry buster after someone/something");
	
//	if(LookupOffset(g_iOffsetSBTarget, "CTFPlayer", "m_iPlayerSkinOverride")) g_iOffsetSBTarget += GameConfGetOffset(hConf, "m_hSBTarget");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x80\x7D\x0C\x00\x56\x8B\xF1", 10);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//MissionType
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);			//StartIdleSount?
	if((g_hSetMission = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Signature Call for CTFBot::SetMission!");
	
	int m_iPlayerSkinOverride = FindSendPropInfo("CTFPlayer", "m_iPlayerSkinOverride");
	int m_hSBTarget = (2407 * 4) - m_iPlayerSkinOverride;
	
	g_iOffsetSBTarget = m_iPlayerSkinOverride + m_hSBTarget;
	
	HookEvent("player_death", Event_BusterDeath, EventHookMode_PostNoCopy);
	HookEvent("post_inventory_application", Event_BusterSpawn);
	
	PrintToServer("m_iPlayerSkinOverride = %i\nm_hSBTarget = %i + %i = %i", m_iPlayerSkinOverride, m_iPlayerSkinOverride, m_hSBTarget, m_iPlayerSkinOverride + m_hSBTarget);	//m_iPlayerSkinOverride = 9048
}

public void OnMapStart()
{
	PrecacheSound(")mvm/sentrybuster/mvm_sentrybuster_intro.wav");
	PrecacheSound(")mvm/sentrybuster/mvm_sentrybuster_explode.wav");
	PrecacheSound(")mvm/sentrybuster/mvm_sentrybuster_spin.wav");
	
	PrecacheModel("models/bots/demo/bot_sentry_buster.mdl");
	
	PrecacheSound("^mvm/sentrybuster/mvm_sentrybuster_step_01.wav"); 
	PrecacheSound("^mvm/sentrybuster/mvm_sentrybuster_step_02.wav"); 
	PrecacheSound("^mvm/sentrybuster/mvm_sentrybuster_step_03.wav"); 
	PrecacheSound("^mvm/sentrybuster/mvm_sentrybuster_step_04.wav");
}

public Action Command_Bust(int client, int argc)
{
	int iClients = 0;
	int iBuildings = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			iClients++;
		}
	}
	
	int iBuilding = -1;
	while((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) != -1)
	{
		iBuildings++;
	}
	
	if(iClients < 32 && iBuildings > 0)
	{
		ServerCommand("tf_bot_add 1 demoman expert \"Sentry Buster\"");
	}
	
	return Plugin_Handled;
}

public void Event_BusterSpawn(Event hEvent, char[] name, bool dontBroadcast)
{
	int buster = GetClientOfUserId(hEvent.GetInt("userid"));
	if(IsFakeClient(buster))
	{
		CreateTimer(0.2, Timer_DoBuster, hEvent.GetInt("userid"));
	}
}

public Action Timer_DoBuster(Handle timer, int userid)
{
	int buster = GetClientOfUserId(userid);
	if(buster != 0)
	{
		//g_bIsBuster[buster] = true;
		
		TF2_BustTarget(buster);
	}
}

public void Event_BusterDeath(Event hEvent, char[] name, bool dontBroadcast)
{
	int buster = GetClientOfUserId(hEvent.GetInt("userid"));
	if(g_bIsBuster[buster])
	{
		//RequestFrame(DeBuster, hEvent.GetInt("userid"));
	}
}

public void DeBuster(int userid)
{
	int buster = GetClientOfUserId(userid);
	if(buster != 0)
	{
	}
}

stock int TF2_BustTarget(int buster)
{
	/*
	T_TFBot_SentryBuster
	{
		Class Demoman
		Name "Sentry Buster"
		Skill Expert
		Health 2500
		Item "The Ullapool Caber"
		WeaponRestrictions MeleeOnly
		ClassIcon sentry_buster
		Attributes MiniBoss
		CharacterAttributes
		{
			"move speed bonus" 2
			"damage force reduction" 0.5
			"airblast vulnerability multiplier" 0.5
			"override footstep sound set" 7
			"cannot be backstabbed" 1
		}
	}
	*/
	if (TF2_GetPlayerClass(buster) == TFClass_Sniper) {
		SDKCall(g_hSetMission, buster, SNIPER, true);
	} else if (TF2_GetPlayerClass(buster) == TFClass_Spy) {
		SDKCall(g_hSetMission, buster, SPY, true);
	} else if (TF2_GetPlayerClass(buster) == TFClass_Engineer) {
		SDKCall(g_hSetMission, buster, ENGINEER, true);
	}
}

stock bool LookupOffset(int &iOffset, const char[] strClass, const char[] strProp)
{
	iOffset = FindSendPropInfo(strClass, strProp);
	if(iOffset <= 0)
	{
		LogMessage("Could not locate offset for %s::%s!", strClass, strProp);
		return false;
	}

	return true;
}