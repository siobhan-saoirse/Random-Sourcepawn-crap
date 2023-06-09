#include <sourcemod>
#include <tf2attributes>


public OnPluginStart()
{

	HookEvent("post_inventory_application", Event_InvApp, EventHookMode_Post);
	
}


public void Event_InvApp(Event event, const char[] name, bool dontBroadcast)
{

	int client = GetClientOfUserId(event.GetInt("userid"));
	TF2Attrib_SetByName(client, "Reload time decreased", 1.0);

}