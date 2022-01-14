#include <sourcemod>
#include <tf2>
#include <sdkhooks>
#include <sdktools>
#include <tf2attributes>

Handle g_hSDKPlayGesture;
new bool:g_bIsCrit[MAXPLAYERS + 1] = { false, ... };
new bool:g_bReloading[MAXPLAYERS + 1] = { false, ... };
new Handle:sv_cheats = INVALID_HANDLE;
new Handle:sway = INVALID_HANDLE;
new Handle:interp = INVALID_HANDLE;

public Plugin:myinfo = 
{
	name = "[TF2] Enhanced Weapon Crap",
	author = "Seamusmario",
	description = "Enhanced Weapon Crap.",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/groups/SEAMSERVER"
}

// most of this was taken from the forums. i don't really own most of the code.
// some of it i wrote from scratch
// credit to everybody

public OnPluginStart()
{
	sv_cheats = FindConVar("sv_cheats");
    sway = FindConVar("cl_wpn_sway_scale");
    interp = FindConVar("cl_wpn_sway_interp");
	AddNormalSoundHook(CritWeaponSH);
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

public Action:CritWeaponSH(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
    //SendConVarValue(entity, FindConVar("r_drawothermodels"), "1");
    //SendConVarValue(entity, sway, "1");
    //SendConVarValue(entity, interp, "0.1");
    int client = entity;
    new hClientWeapon = GetEntPropEnt(entity, Prop_Send, "m_hActiveWeapon");
    char clsname[256]; 
    GetEntityClassname(hClientWeapon,clsname,sizeof(clsname))
    if (GetConVarInt(FindConVar("sv_client_predict")) == 0) {
        if (StrContains(sample,"weapon",false) != -1 && StrContains(sample,"reload",false) == -1 && hClientWeapon != GetPlayerWeaponSlot(client, 2)) {

            PrecacheSound(sample);
            EmitSoundToAll(sample,entity,channel,level,flags,volume,pitch);
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
        if (StrContains(sample,"weapon",false) != -1 && (StrContains(sample,"swing",false) != -1 || StrContains(sample,"miss",false) != -1)) {

            PrecacheSound(sample);
            EmitSoundToAll(sample,entity,channel,level,flags,volume,pitch);
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
            EmitSoundToAll(sample,entity,channel,level,flags,volume,pitch);
            return Plugin_Changed;
        }
        if (StrContains(sample,"weapon",false) != -1 && (StrContains(sample,"swing",false) != -1 || StrContains(sample,"miss",false) != -1)) {

            PrecacheSound(sample);
            EmitSoundToAll(sample,entity,channel,level,flags,volume,pitch);
            return Plugin_Changed;
        }
    }
    if (StrContains(sample,"weapon",false) != -1 && StrContains(sample,"pan",false) != -1) {

            PrecacheSound(sample);
            EmitSoundToAll(sample,entity,SNDCHAN_WEAPON,level,flags,0.5,pitch);
            return Plugin_Changed;
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
        || StrEqual(clsname,"tf_weapon_revolver")) {
            if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                SetAnimation(client,"ACT_MP_RELOAD_SWIM_SECONDARY",2,3)
            } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                SetAnimation(client,"ACT_MP_RELOAD_CROUCH_SECONDARY",2,3)
            } else {
                SetAnimation(client,"ACT_MP_RELOAD_STAND_SECONDARY",2,3)
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
public Action:TF2_CalcIsAttackCritical(client, weapon, String:weaponname[], &bool:result)
{
	new weaponindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
    new hClientWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    char clsname[256]; 
    GetEntityClassname(hClientWeapon,clsname,sizeof(clsname))
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
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_PRIMARY",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_ATTACK_CROUCH_PRIMARY",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_ATTACK_STAND_PRIMARY",2,3)
                    }
                }
                result = true;
                g_bIsCrit[client] = true;
                return Plugin_Handled;
            } else {
                result = false;
                g_bIsCrit[client] = false;
                return Plugin_Handled;      
            }
        }
    }
    if (!StrEqual(clsname,"tf_weapon_knife") && hClientWeapon == GetPlayerWeaponSlot(client, 2)) {
        if (!TF2Attrib_GetByName(hClientWeapon, "crit mod disabled")) {
            if (GetRandomInt(1,3) == 1) { 
                if (StrEqual(clsname,"tf_weapon_fists")) {
                    if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2) {
                        SetAnimation(client,"ACT_MP_ATTACK_CROUCH_MELEE_SECONDARY",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_ATTACK_CROUCH_MELEE_SECONDARY",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_ATTACK_STAND_MELEE_SECONDARY",2,3)
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
                        SetAnimation(client,"ACT_MP_ATTACK_SWIM_MELEE_ALLCLASS",2,3)
                    } else if(GetEntProp(client, Prop_Send, "m_bDucked")) {
                        SetAnimation(client,"ACT_MP_ATTACK_CROUCH_MELEE_ALLCLASS",2,3)
                    } else {
                        SetAnimation(client,"ACT_MP_ATTACK_STAND_MELEE_ALLCLASS",2,3)
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
            } else {
                result = false;
                g_bIsCrit[client] = false;
                return Plugin_Handled;      
            }
        }
    }

	return Plugin_Continue;
}