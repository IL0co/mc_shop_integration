#include <sourcemod>
#include <mc_core>
#include <shop>

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

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{	
	__pl_shop_SetNTVOptional();
	MarkNativeAsOptional("Shop_SetHide");
    
	return APLRes_Success;
}

public void OnPluginEnd()
{
    Shop_UnregisterMe();
}

public void MC_OnPluginUnRegistered(const char[] plugin_id, MC_PluginIndex plugin_index)
{
    Shop_UnregisterMe();
    Shop_Started();
}

public void OnPluginStart()
{
	LoadTranslations("mc_core.phrases");

    char buffer[256];
	BuildPath(Path_SM, buffer, sizeof(buffer), "configs/multi-core/settings_shop.cfg");

	g_kvItems = new KeyValues("Shop Config");
	if(!g_kvItems.ImportFromFile(buffer))
		SetFailState("%T", "ERROR FILE DOES NOT EXISTS", 0, buffer);
    
    if(Shop_IsStarted())
        Shop_Started();
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
}

public void MC_OnPluginRegistered(const char[] plugin_id, MC_PluginIndex plugin_index)
{
    Load_Shop(plugin_id);
}

stock void Load_Shop(const char[] plugin_id)
{
	if(!plugin_id[0])
		return;
	
	g_kvItems.Rewind();
	if(!g_kvItems.GotoFirstSubKey())
        return;

	// if(map.DontLoadInCores & Core_Shop)
	// 	return;

    MC_PluginIndex plugin_index = MC_GetPluginIndexFromId(plugin_id);
	char category_unique[MAX_UNIQUE_LENGTH], category_name[MAX_UNIQUE_LENGTH], item[MAX_UNIQUE_LENGTH], in_category[MAX_UNIQUE_LENGTH];
	CategoryId category_id;
	int pos;

	ArrayList ar = MC_GetPluginItemsArrayList(plugin_index);

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
                Shop_SetCallbacks(_, CallBack_Shop_OnItemToggled, _, CallBack_Shop_OnItemDisplay, .preview = (MC_IsItemHavePreview(plugin_index, item) ? CallBack_Shop_OnItemPreview : INVALID_FUNCTION));
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
	if(MC_GetItemDisplayName(client, Get_CategoryUniqueOfThisItem(category, item_unique), item_unique, buffer, maxlen))
		return true;

	return false;
}

public void CallBack_Shop_OnItemPreview(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item_unique)
{
	MC_CallItemPreview(client, Get_CategoryUniqueOfThisItem(category, item_unique), item_unique);
}

public ShopAction CallBack_Shop_OnItemToggled(int client, CategoryId category_id, const char[] category, ItemId item_id, char[] item_unique, bool isOn, bool elapsed)
{
	// MC_PluginMap plugin_map;
	// if(!GetPluginMap(plugin_id, plugin_map))
	// 	return Shop_Raw;

	// MC_ItemMap item_map = plugin_map.GetItemMap(item_unique);

	if(isOn || elapsed)
	{
		// if(CallBack_OnItemSelected(client, plugin_map, item_map, plugin_id, "", Core_Shop))
        MC_SetClientSelectedItem(client, Get_CategoryUniqueOfThisItem(category, item_unique), Shop, "");
			
		return Shop_UseOff;
	}
		
	// if(CallBack_OnItemSelected(client, plugin_map, item_map, plugin_id, item_unique, Core_Shop))
    MC_SetClientSelectedItem(client, Get_CategoryUniqueOfThisItem(category, item_unique), Shop, item_unique);

	return Shop_UseOn;
}

MC_PluginIndex Get_CategoryUniqueOfThisItem(const char[] shop_category, const char[] item)	
{
	if(MC_IsValidPluginUnique(shop_category))
		return MC_GetPluginIndexFromId(shop_category);
	
    g_kvItems.Rewind();
    g_kvItems.JumpToKey(shop_category);
    g_kvItems.JumpToKey(item);

    char plugin_id[MAX_UNIQUE_LENGTH];
    g_kvItems.GetString("In Category", plugin_id, sizeof(plugin_id));
	
	if(MC_IsValidPluginUnique(plugin_id))
		return MC_GetPluginIndexFromId(plugin_id);

    return INVALID_PLUGIN_INDEX;
}