#include <sourcemod>
#include <mc_core>
#include <shop>
#include <clientprefs>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
	name		= "[Multi-Core] Shop Integration",
	author	  	= "iLoco",
	description = "Интеграция Multi-Core в Shop Fork",
	version	 	= "0.0.0",
	url			= "http://hlmod.ru"
};

KeyValues g_kvItems;
StringMap g_mapCookies;

#define CORE_TYPE "shop"

public void OnPluginEnd()
{
    Shop_UnregisterMe();
	MC_UnRegisterMe();
}

public void MC_OnPluginUnRegistered(const char[] plugin_id)
{
	Cookie cookie;
	if(g_mapCookies.GetValue(plugin_id, cookie) && cookie)
	{
		g_mapCookies.Remove(plugin_id);
		delete cookie;
	}
		
    Shop_UnregisterMe();
    Shop_Started();
}

public void OnPluginStart()
{
    g_mapCookies = new StringMap();
	LoadTranslations("mc_core.phrases");

    char buffer[256];
	BuildPath(Path_SM, buffer, sizeof(buffer), "configs/multi-core/settings_shop.cfg");

	g_kvItems = new KeyValues("Shop Config");
	if(!g_kvItems.ImportFromFile(buffer))
		SetFailState("%T", "ERROR FILE DOES NOT EXISTS", 0, buffer);
    
    if(Shop_IsStarted())
        Shop_Started();
}

public void MC_OnCoreLoaded()
{
	MC_RegisterIntegration(CORE_TYPE, CallBack_MC_OnIntegrationGetItem);
}

public bool CallBack_MC_OnIntegrationGetItem(int client, const char[] plugin_id, char[] buffer, int maxlen)
{
	Cookie cookie;
	g_mapCookies.GetValue(plugin_id, cookie);
	cookie.Get(client, buffer, maxlen);

	if(buffer[0])
		return true;

	return false;
}

public void MC_OnPluginRegistered(const char[] plugin_id)
{
	char buff[MAX_UNIQUE_LENGTH];
	FormatEx(buff, sizeof(buff), "VIP:%s", plugin_id);

	g_mapCookies.SetValue(plugin_id, new Cookie(buff, buff, CookieAccess_Private));

    Load_Shop(plugin_id);
}

public void Shop_Started()
{   
    ArrayList ar = MC_GetPluginIdsArrayList();
	char plugin_id[MAX_UNIQUE_LENGTH];

	for(int index; index < ar.Length; index++)
	{
		ar.GetString(index, plugin_id, sizeof(plugin_id));
		Load_Shop(plugin_id);
	}

    delete ar;
}

stock void Load_Shop(const char[] plugin_id)
{
	if(!plugin_id[0])
		return;
	
	g_kvItems.Rewind();
	if(!g_kvItems.GotoFirstSubKey())
        return;

	char category_unique[MAX_UNIQUE_LENGTH], category_name[MAX_UNIQUE_LENGTH], item[MAX_UNIQUE_LENGTH], in_category[MAX_UNIQUE_LENGTH];
	CategoryId category_id;
	int pos;

	ArrayList ar = MC_GetPluginItemsArrayList(plugin_id);

    do
    {
        g_kvItems.GetSectionName(category_unique, sizeof(category_unique));
        g_kvItems.GetString("Name", category_name, sizeof(category_name));

        g_kvItems.SavePosition();
        if(g_kvItems.GotoFirstSubKey())
        {
            category_id = Shop_RegisterCategory(category_unique, (category_name[0] ? category_name : category_unique), "");

            do
            {
                g_kvItems.GetSectionName(item, sizeof(item));

                if((pos = ar.FindString(item)) == -1)
                {
                    continue;
                }

                if(strcmp(category_unique, plugin_id, false) != 0)
                {
                    g_kvItems.GetString("In Category", in_category, sizeof(in_category));
                    
                    if(!in_category[0] || strcmp(in_category, plugin_id, false) != 0)
                    {
                        continue;
                    }
                }
                
                if(!Shop_StartItem(category_id, item))
                {
                    continue;
                }

                Shop_SetInfo(item, "", g_kvItems.GetNum("Price"), g_kvItems.GetNum("Sell Price"), Item_Togglable, g_kvItems.GetNum("Duration"), g_kvItems.GetNum("Gold Price"), g_kvItems.GetNum("Gold Sell Price"));
                Shop_SetLuckChance(g_kvItems.GetNum("Luck Chance"));
                Shop_SetCallbacks(_, CallBack_Shop_OnItemToggled, _, CallBack_Shop_OnItemDisplay, .preview = (MC_IsItemHavePreview(plugin_id, item) ? CallBack_Shop_OnItemPreview : INVALID_FUNCTION));
                Shop_SetHide(view_as<bool>(g_kvItems.GetNum("Hide", 0)));
                Shop_EndItem();

                ar.Erase(pos);
            }
            while(g_kvItems.GotoNextKey());
        
            g_kvItems.GoBack();
        }
    }
    while(g_kvItems.GotoNextKey());

	delete ar;
}

public bool CallBack_Shop_OnItemDisplay(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item_unique, ShopMenu menu, bool &disabled, const char[] name, char[] buffer, int maxlen)
{
    char plugin_id[MAX_UNIQUE_LENGTH];
    Get_CategoryUniqueOfThisItem(category, item_unique, plugin_id, sizeof(plugin_id));

	if(MC_GetItemDisplayName(client, plugin_id, CORE_TYPE, item_unique, buffer, maxlen))
		return true;

	return false;
}

public void CallBack_Shop_OnItemPreview(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item_unique)
{
    char plugin_id[MAX_UNIQUE_LENGTH];
    Get_CategoryUniqueOfThisItem(category, item_unique, plugin_id, sizeof(plugin_id));
    
	MC_CallItemPreview(client, plugin_id, item_unique, CORE_TYPE);
}

public ShopAction CallBack_Shop_OnItemToggled(int client, CategoryId category_id, const char[] category, ItemId item_id, char[] item_unique, bool isOn, bool elapsed)
{
    char plugin_id[MAX_UNIQUE_LENGTH];
    Get_CategoryUniqueOfThisItem(category, item_unique, plugin_id, sizeof(plugin_id));
    
    Cookie cookie;
    g_mapCookies.GetValue(plugin_id, cookie);

	if(isOn || elapsed)
	{
        cookie.Set(client, "");
			
		return Shop_UseOff;
	}
		
    cookie.Set(client, item_unique);

	return Shop_UseOn;
}

bool Get_CategoryUniqueOfThisItem(const char[] shop_category, const char[] item, char[] plugin_id, int maxlen)	
{
	if(MC_IsValidPluginUnique(shop_category))
    {
        FormatEx(plugin_id, maxlen, shop_category);
        return true;
    }
	
    g_kvItems.Rewind();
    g_kvItems.JumpToKey(shop_category);
    g_kvItems.JumpToKey(item);

    g_kvItems.GetString("In Category", plugin_id, maxlen);
	
	if(MC_IsValidPluginUnique(plugin_id))
		return true;

    return false;
}