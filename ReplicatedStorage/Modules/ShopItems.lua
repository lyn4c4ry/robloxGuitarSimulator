-- @ScriptType: ModuleScript
--[[
    ShopItems.lua
    ReplicatedStorage/Modules/ShopItems

    Buy sekmesinde satılacak ürünlerin listesi. Yeni ürün eklemek için
    bu tabloya yeni bir satır eklemek yeterli; UI ve BuyHandler otomatik
    olarak okuyacak şekilde tasarlandı.

    AllowMultiple = true  -> "Buy 1x" yanında "Buy Multiple" seçeneği de çıkar (miktar girilebilir)
    AllowMultiple = false -> sadece "Buy 1x" çıkar, çoklu alım yapılamaz
]]

return {
	{
		Id = "TuningPegs",
		Name = "Akort Anahtarı Seti",
		Icon = "rbxassetid://0", -- TODO: kendi icon asset id'ni koy
		Price = 15,
		Currency = "Money",
		Description = "Gitar montajında kullanılan akort anahtarı seti. Classic Acoustic Guitar tarifinde gerekir.",
		AllowMultiple = true,
	},
	{
		Id = "RareWoodPack",
		Name = "Nadir Ahşap Paketi",
		Icon = "rbxassetid://0",
		Price = 200,
		Currency = "Money",
		Description = "Standart odundan daha değerli, ileri seviye gitarlar için kullanılan özel ahşap paketi.",
		AllowMultiple = false, -- tek seferde 1 adet alınabilir
	},
	{
		Id = "GuitarStrings",
		Name = "Gitar Telleri (Set)",
		Icon = "rbxassetid://0",
		Price = 8,
		Currency = "Money",
		Description = "6 telden oluşan yedek tel seti. Akort mini-oyunundan önce gereklidir.",
		AllowMultiple = true,
	},
}