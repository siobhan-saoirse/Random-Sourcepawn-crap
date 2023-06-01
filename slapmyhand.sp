#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#pragma semicolon 1

public Plugin:myinfo =
{
	name = "[TF2] Unused h5 lines",
	author = "Pelipoika",
	description = "Missing in action.",
	version = "1.1",
	url = "http://wiki.teamfortress.com/wiki/Spy_responses#Unused_responses"
};

public OnPluginStart()
{
	AddNormalSoundHook(NormalSHook:Sound);
}

public OnMapStart()
{
	PrecacheSound("vo/taunts/spy_highfive01.mp3");
	PrecacheSound("vo/taunts/spy_highfive02.mp3");
	PrecacheSound("vo/taunts/spy_highfive03.mp3");
	PrecacheSound("vo/taunts/spy_highfive04.mp3");
	PrecacheSound("vo/taunts/spy_highfive05.mp3");
	PrecacheSound("vo/taunts/spy_highfive06.mp3");
	PrecacheSound("vo/taunts/spy_highfive07.mp3");
	PrecacheSound("vo/taunts/spy_highfive08.mp3");
	PrecacheSound("vo/taunts/spy_highfive09.mp3");
	PrecacheSound("vo/taunts/spy_highfive10.mp3");
	PrecacheSound("vo/taunts/spy_highfive11.mp3");
	PrecacheSound("vo/taunts/spy_highfive12.mp3");
	PrecacheSound("vo/taunts/spy_highfive13.mp3");
	PrecacheSound("vo/taunts/spy_highfive14.mp3");
	
	PrecacheSound("vo/heavy_mvm_rage01.mp3");
	PrecacheSound("vo/heavy_mvm_rage02.mp3");
	PrecacheSound("vo/heavy_mvm_rage03.mp3");
	PrecacheSound("vo/heavy_mvm_rage04.mp3");
	
	PrecacheSound("vo/taunts/pyro_highfive01.mp3");
	PrecacheSound("vo/taunts/pyro_highfive02.mp3");
	PrecacheSound("vo/taunts/pyro_highfive_success01.mp3");
	PrecacheSound("vo/taunts/pyro_highfive_success02.mp3");
	PrecacheSound("vo/taunts/pyro_highfive_success03.mp3");
	
	PrecacheSound("vo/taunts/spy_highfive_success01.mp3");
	PrecacheSound("vo/taunts/spy_highfive_success02.mp3");
	PrecacheSound("vo/taunts/spy_highfive_success03.mp3");
	PrecacheSound("vo/taunts/spy_highfive_success04.mp3");
	PrecacheSound("vo/taunts/spy_highfive_success05.mp3");
}

public Action:Sound(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &ent, &channel, &Float:volume, &level, &pitch, &flags)
{
	if (!IsValidEntity(ent) && ent < 1 || ent > MaxClients || channel < 1)
		return Plugin_Continue;
		
	if (IsValidClient(ent))
	{
		if(TF2_GetPlayerClass(ent) == TFClass_Spy)
		{
			if(StrContains(sample, "vo/taunts/spy_highfive_success", false) != -1)
			{
				Format(sample, sizeof(sample), "vo/taunts/spy_highfive_success0%i.mp3", GetRandomInt(1, 5));
				return Plugin_Changed;
			}
			else if(StrContains(sample, "vo/taunts/spy_highfive", false) != -1)
			{
				switch(GetRandomInt(1,2))
				{
					case 1: Format(sample, sizeof(sample), "vo/taunts/spy_highfive0%i.mp3", GetRandomInt(1, 9));
					case 2: Format(sample, sizeof(sample), "vo/taunts/spy_highfive%i.mp3", GetRandomInt(10, 14));
				}
				return Plugin_Changed;
			}
		}
		else if(TF2_GetPlayerClass(ent) == TFClass_Pyro)
		{
			if(StrContains(sample, "vo/taunts/pyro_highfive_success", false) != -1)
			{
				Format(sample, sizeof(sample), "vo/taunts/pyro_highfive_success0%i.mp3", GetRandomInt(1, 3));
				return Plugin_Changed;
			}
			else if(StrContains(sample, "vo/taunts/pyro_highfive", false) != -1)
			{
				Format(sample, sizeof(sample), "vo/taunts/pyro_highfive0%i.mp3", GetRandomInt(1, 2));
				return Plugin_Changed;
			}
		}
		else if(TF2_GetPlayerClass(ent) == TFClass_Heavy)
		{
			if(StrContains(sample, "vo/heavy_battlecry03", false) != -1)
			{
				Format(sample, sizeof(sample), "vo/heavy_mvm_rage0%i.mp3", GetRandomInt(1, 4));
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}

stock bool:IsValidClient(client)
{
	if (client <= 0 || client > MaxClients) return false;
	return IsClientInGame(client);
}