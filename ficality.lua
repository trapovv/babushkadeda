local ok_ui, Fatality = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/4lpaca-pin/Fatality/refs/heads/main/src/source.luau"))()
end)
if not ok_ui or not Fatality then warn("[Fekality] Fatality failed: "..tostring(Fatality)); return end
local Notifier; pcall(function() Notifier = Fatality:CreateNotifier() end)
pcall(function() Fatality:Loader({ Name = "Fekality", Duration = 2 }) end)

local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local MPS=game:GetService("MarketplaceService")
local LP=Players.LocalPlayer
local Camera=Workspace.CurrentCamera
local PG=LP:WaitForChild("PlayerGui")

-- ============ Nickname privacy (v3: replaces LP nick text with "Скрыто") ============
-- GUI не выключается. Находим TextLabel/TextButton, чей Text == LP.Name или LP.DisplayName,
-- и подменяем текст. Оригинал кешируется для отката по тогглу.
local NICK = { Hide = true, FakeText = "Скрыто" }
local _origText = {}  -- map: TextLabel -> original text
local _nickConns = {} -- per-label .Changed connections (to defend against game rewriting it)

local function _isNickLabel(c)
    if not (c:IsA("TextLabel") or c:IsA("TextButton")) then return false end
    local t = tostring(c.Text or "")
    if t == "" then return false end
    if t == NICK.FakeText then return false end  -- already patched by us
    local n  = LP.Name or ""
    local dn = LP.DisplayName or ""
    if n  ~= "" and (t == n  or t:find(n,  1, true)) then return true end
    if dn ~= "" and (t == dn or t:find(dn, 1, true)) then return true end
    return false
end

local function _patchLabel(c)
    if _origText[c] == nil then _origText[c] = c.Text end
    pcall(function() c.Text = NICK.FakeText end)
    -- self-healing: if game overwrites the text back to the nick, re-replace
    if not _nickConns[c] then
        _nickConns[c] = c:GetPropertyChangedSignal("Text"):Connect(function()
            if not NICK.Hide then return end
            local cur = tostring(c.Text or "")
            if cur ~= NICK.FakeText then
                if _isNickLabel(c) then
                    _origText[c] = cur
                    pcall(function() c.Text = NICK.FakeText end)
                end
            end
        end)
    end
end

local function _scanRoot(root)
    if not root then return end
    local ok, kids = pcall(function() return root:GetDescendants() end)
    if not ok or not kids then return end
    for _, d in ipairs(kids) do
        if _isNickLabel(d) then _patchLabel(d) end
    end
end

local function applyNickHide()
    if NICK.Hide then
        _scanRoot(LP.Character)
        _scanRoot(PG)
        _scanRoot(workspace)
    else
        for lbl, orig in pairs(_origText) do
            if lbl and lbl.Parent then pcall(function() lbl.Text = orig end) end
            _origText[lbl] = nil
        end
        for lbl, conn in pairs(_nickConns) do
            pcall(function() conn:Disconnect() end)
            _nickConns[lbl] = nil
        end
    end
end

-- periodic re-scan: catches new nameplates the game spawns after script load
task.spawn(function()
    while true do
        task.wait(1.0)
        if NICK.Hide then
            _scanRoot(LP.Character)
            _scanRoot(workspace)
        end
    end
end)

-- live watcher: scan new descendants in workspace (covers respawn / new player GUIs)
workspace.DescendantAdded:Connect(function(d)
    if NICK.Hide and (d:IsA("TextLabel") or d:IsA("TextButton")) then
        task.wait(0.05)
        if _isNickLabel(d) then _patchLabel(d) end
    end
end)

applyNickHide()
task.delay(0.5, applyNickHide)
task.delay(1.5, applyNickHide)
LP.CharacterAdded:Connect(function()
    task.wait(0.3)
    applyNickHide()
    task.delay(0.6, applyNickHide)
end)


local LEG_COLOR=Color3.new(1,0.705882,0)
local COLOR_TOL=0.1
local function isLegColor(c)
    return math.abs(c.R-LEG_COLOR.R)<COLOR_TOL
       and math.abs(c.G-LEG_COLOR.G)<COLOR_TOL
       and math.abs(c.B-LEG_COLOR.B)<COLOR_TOL
end

local function looksLikeUuid(s)
    -- Reject hex-UUID-style names like E2D70A60-BBEF-4581-A4A4-E0D8C1EE8B85
    -- или с подчёркиваниями. Обычные названия проходят нетронутыми.
    if not s or #s < 12 then return false end
    -- 8-4-4-4-12 hex с - или _
    if s:match("^%x%x%x%x%x%x%x%x[%-_]%x%x%x%x[%-_]%x%x%x%x[%-_]%x%x%x%x[%-_]%x%x%x%x%x%x%x%x%x%x%x%x$") then
        return true
    end
    -- 5 блоков hex через - или _
    if s:match("^%x+[%-_]%x+[%-_]%x+[%-_]%x+[%-_]%x+$") then return true end
    -- 3+ блока hex и всё в хекс-диапазоне + разделители
    if s:match("^%x+[%-_]%x+[%-_]%x+") and not s:match("[g-zG-Z]") then return true end
    return false
end

local S={On=false,Chrome=true,FontSize=12,BoxWidth=130,MaxDist=180,MaxVisible=25,
    Transparency=0.45,Search="",MatchOnly=false,
    PickedColor=Color3.fromRGB(255,215,0),Color=Color3.fromRGB(255,215,0)}
local TAGS={}
local CONNS={}
local nameCache={}
local pendingQueue={}
local ITEM_DB={[6384915788]="Number(N)ine Vintage T-Shirt",[12001043365]="ERD Distressed Zip Jacket",[18662896578]="Yandex Delivery T-Shirt",[7798271981]="Chigura Jacket",[7798302571]="Chigura Pants",[18391376326]="ERD Archive Trousers",[2887711548]="Cav Empt T-Shirt Spring Delivery",[3244925440]="Cav Empt Sweatshirt Symptom Heavy",[297942903]="Cav Empt Bomber",[914784455]="Cav Empt Sweatshirt FW 17",[322189906]="Cav Empt Not Impossible Crewneck",[1002344605]="Cav Empt MD Document Crewneck",[18280893525]="Cav Empt Joker",[6004029876]="Haliky Hoodie",[6676412081]="Haliky Gang Bears",[8801995627]="Nike Tech Dark Light Blue",[15501893721]="Nike Tech Dark Blue",[7397565263]="Nike Tech Windrunner Black",[75749441655962]="redvetements",[87630874548849]="Gallery Dept Lanvin",[79423109019674]="Gallery Dept Sweatshirt Blue",[118666889439649]="Gallery Dept Sweatshirt Brown",[86921710360798]="Gallery Dept Red Zip-Hoodie",[140022990256816]="Gallery Dept Hoodie Green",[100168311309116]="Gallery Dept Shaman T-Shirt",[1352050969]="Prada Re-Nylon Jacket",[114724377]="ERD Skull Denim Jacket",[4843433327]="BAPE Yellow Camo Shark",[3052304894]="BAPE Tiger Camo",[85037105009809]="BAPE Red Panda",[1329266704]="BAPE Full Zip Shark",[72015381801594]="BAPE Tiger Pants Blue",[137022318888712]="BAPE Tiger Pants Red",[131922684973046]="BAPE Tiger Pants Dark Green",[99313817373559]="BAPE Tiger Pants Purple",[86664943903751]="Gutta Raiders Camo shirt",[75621017852847]="Gutta Opiy Shirt",[70895461143874]="Gutta Snake Year",[9930373240]="NeNet T-Shirt Purple",[118840925833484]="NeNet T-Shirt Gray",[93422277147402]="HBA Creepy Sweatshirt",[71222633992816]="HBA Shirt",[1103783724]="Bape x Supreme",[13444831702]="Supreme x BB",[15706847548]="Gosha Rubchinskiy x Rassvet",[87503337904060]="Gosha Rubchinskiy Fila Yellow LS",[5487023113]="Gosha Rubchinskiy Enemy Sweater Black",[15311273900]="Gosha Rubchinskiy X Kappa Sweater",[9545499629]="Gosha Rubchinskiy Sweater Blue",[560325377]="Gosha Rubchinskiy Hoodie ColorBrick",[576444465]="Gosha Rubchinskiy Camo Save Preserve",[436720176]="Gosha Rubchinskiy X Thrasher",[4996937439]="Gosha Rubchinskiy Zip Red/Blue",[2118764687]="Gosha Rubchinskiy Vdrug Red",[772695241]="Gosha Rubchinskiy Green Sweater",[607550981]="Gosha Rubchinskiy Sport Jacket Russian",[1162019947]="Gosha Rubchinskiy x Kappa Vintage",[5549063618]="Gosha Rubchinskiy Sweater Yellow",[14578854678]="Gosha Rubchinskiy Hybrid",[5972477579]="Gosha Rubchinskiy Christmas",[107248336623941]="Gosha Rubchinskiy Vdrug Drug",[98305906232207]="Gosha Rubchinskiy Flags",[1824185908]="Gosha Rubchinskiy x Kappa",[11796928325]="Gosha Rubchinskiy Christmas",[884721414]="Gosha Rubchinskiy x Kappa",[15903662503]="Polo Burberry",[13868676222]="Burberry x Bape",[6071739662]="Off-White Virgil Abloh Red",[3224293759]="Off-White Green",[1213373791]="Off-White Camo",[590131471]="Off-White Beige",[2474144253]="Off-White MonoLisa",[2518177916]="Off-White Sweater",[15084872864]="Off-White Black T-Shirt v2",[4809072541]="Off-White White T-Shirt v2",[138024345748614]="Off-White White T-Shirt v3",[6274614487]="Palm Angels Sweatshirt Light Blue",[127026922296813]="Palm Angels T-Shirt v2",[11511640247]="Palm Angels T-Shirt v3",[126190832806951]="Palm Angels Zip Red",[5611331869]="Palm Angels Flame",[6501833600]="Palm Angels Zip Flower",[7205233886]="Palm Angels Zip Acid",[89385145596759]="Palm Angels Zip Purple",[88741221455613]="Palm Angels x Raf Blue Red",[9084664827]="Palm Angels Purple",[123772691907841]="Comme des Garcons Shirt",[8128676575]="Comme des Garcons T-Shirt Camo Love",[81585264094038]="Comme des Garcons Play T-Shirt Black",[2098915079]="Comme des Garcons T-Shirt Love White",[15121388536]="Comme des Garcons T-Shirt Black",[1074658737]="Comme des Garcons Blue Zip-Hoodie",[1079296706]="Comme des Garcons T-Shirt White-Red",[962194504]="Comme des Garcons Longsleeve White-Blue",[116168634401177]="Comme des Garcons X Rolling Stones T-Shirt",[87509417534862]="Stone Island Zip-Hoodie",[14840856758]="Stone Island Orange",[14984408119]="Stone Island Pink",[117161695009647]="Stone Island Off Day Blue",[97856390601463]="Stone Island Red Hoodie Off Dye",[119767338320263]="Stone Island Comfort Tech Purple",[12624379885]="Stone Island Turtleneck",[7249098507]="Stone Island Urban Black Yellow",[8462301101]="Stone Island Desert Camo",[8631651981]="Stone Island Desert Camo Jacket",[8631755151]="Stone Island WATRO-TC Jacket",[13778721268]="Stone Island Skin Touch Purple",[132959748946564]="Stone Island Shadow Tiger Camo",[139421353405484]="Stone Island Reflective",[118064352416891]="Stone Island Comfort Tech Blue",[120903225671360]="Stone Island Comfort Tech Red",[139017627542362]="Stone Island x Supreme White",[13876916079]="Stone Island x Supreme",[8631671234]="Stone Island Big Loom Camo-Tc",[831537199]="Stone Island Navy",[8631687945]="Stone Island Desert Camo",[8631779037]="Stone Island WATRO-TC",[13779001426]="Stone Island Purple Skin Touch",[108047896837515]="Stone Island x Supreme White",[84913974138865]="Stone Island x Supreme",[8631708424]="Stone Island Big Loom Camo-Tc",[82077729005226]="CP.Company Blue Puffer Jacket",[78185107533537]="CP.Company DD Shell Red",[97526151621254]="CP.Company Teal Jumper",[131336649441063]="CP.Company Navy Windbreaker",[113247621156859]="CP.Company Black Windbreaker",[100997096188512]="CP.Company DD Shell Green",[139627508845654]="CP.Company DD Shell Beige",[99737839478071]="CP.Company Cardigan Black",[15783597851]="CP.Company Crewneck",[134908184079208]="CP.Company Carbone Noir",[16974632408]="CP.Company Orange Pants",[118245234493513]="Racer WorldWide Leopard Zip-Hoodie",[99497707297997]="Racer WorldWide Sheepskin Jacket",[97197585182330]="Racer WorldWide Longsleeve Katya Kishchuk",[75548914998494]="Racer Worldwide Metallic Sweatpants",[124377088956183]="Racer Worldwide Light Jeans",[82685608298333]="Racer Worldwide Sweatpants",[138030819896058]="Racer Worldwide Transform Zip Jeans",[6046174032]="Yohji Yamamoto Ys for Men AW2001 Godzilla",[14484000414]="Yohji Yamamoto Rei Ayanami Evangelion Button up",[86114857882709]="Yohji Yamamoto Sweatshirt Avant Garde",[115386784245524]="Yohji Yamamoto Green Jacket",[131596879156451]="Yohji Yamamoto Sweatshirt Leather",[10515393675]="Yohji Yamamoto Sweatshirt Spider Knit",[4794620897]="Yohji Yamamoto AW 2001 Godzilla Sweatshirt",[4895301337]="Yohji Yamamoto Heroes Leather Biker Jacket",[5166805206]="Yohji Yamamoto Sweatshirt Skull",[130582847343989]="Yohji Yamamoto Sweatshirt Supreme",[90420982954859]="Yohji Yamamoto Jacket Dark Blue",[8826223539]="Yohji Yamamoto Sweatshirt Smoke",[129487569430492]="Yohji Yamamoto J-PT Illustration",[89357762722807]="Yohji Yamamoto Project T-Shirt",[132752004376816]="Yohji Yamamoto Red Jacket",[18606916311]="Yohji Yamamoto Trousers",[71399636217265]="SS04 Yohji Yamamoto Y-3 x 3S Spotted Jeans",[5680301087]="Gucci Tiger Tracksuit",[1518645608]="Gucci Tiger Hoodie",[5469366412]="Gucci Polo Shake",[6181344251]="Gucci Star Sweater",[1081054870]="Gucci Coco Capitan",[3370349046]="Gucci X Tee",[2109554081]="Gucci x LV Jacket",[126913643075376]="Gucci Blind For Love Hoodie",[1083553649]="Gucci Sweatshirt Planet",[134853942496739]="Zapatillas Gucci X Amiri",[5836356644]="LV x TNF",[5226567379]="Supreme x LV",[1565502112]="Supreme x Bape x LV",[967030317]="LV Balmains",[102510983142980]="Balenciaga x Fortnite",[10890916980]="Balenciaga Campaign",[3138759121]="Balenciaga x Gucci",[12774350601]="Balenciaga GAMER",[16648632315]="Balenciaga GAMER Denim Jacket",[17750429143]="Balenciaga GAMER Bomber",[5314403333]="Balenciaga Jean Jacket X Gosha",[17747885612]="Balenciaga X Under Armor",[15453420630]="Balenciaga Speed Runner Hoodie",[137408844484403]="Balenciaga 3B Sports Deutsche Bahn",[3785693796]="Balenciaga Grey Jumper",[16648534764]="Balenciaga Resort 2023",[13676876569]="Balenciaga Distressed Hoodie",[2074367265]="TH Hoodie X Balenciaga x RAF",[98869180278083]="Balenciaga Tokyo Cut",[82170977556685]="Balenciaga Nasa Bomber Jacket",[86463016923018]="Balenciaga Hoodie Alien",[85720763562074]="Balenciaga Runway Polo Hoodie",[15825720946]="Balenciaga Logo Print Hoodie Blue",[133873637543203]="Balenciaga Red Crimson Windbreaker",[18813584989]="Balenciaga Reversible Bomber Jacket",[4590342423]="Balenciaga Paris Moon Sweater",[125248485368695]="Balenciaga Paris",[16662225397]="Balenciaga Runway",[122599601118964]="Balenciaga Jeans",[109107120274465]="Balenciaga Under Armor",[93824635464666]="Balenciaga Grey Skater Sweatpants",[124975585838444]="Balenciaga Blue Skater Sweatpants",[15732426819]="Balenciaga Red Skater Sweatpants",[84116395504704]="Balenciaga Leather",[14072460187]="Balenciaga Gamer Jeans",[97665782669251]="Balenciaga NASA",[8573407398]="Rick Owens x Moncler",[71424043928165]="Rick Owens Denim Red",[130104280419383]="Rick Owens Denim Yellow",[121618494628389]="Rick Owens Zip Denim Pink",[83255075167663]="Rick Owens T-Shirt Vamp",[8502567669]="Rick Owens Runway",[84825703583648]="Rick Owens Pink Jeans",[101535348409637]="Rick Leather",[10322816406]="Chrome Hearts Rainbow Cross",[6678207951]="Chrome Hearts Gray Sweater",[99324171797960]="Chrome Hearts Red Shirt",[16919855258]="Chrome Hearts Multi-Colour Hoodie",[96585015209179]="Chrome Hearts T Logo USA Hoodie",[6198234501]="Chrome Hearts Zip Up Black",[18968804462]="Chrome Hearts Grunge",[72762590768448]="Chrome Hearts Camo Matty",[5944585429]="Chrome Hearts x Off-White Hoodie",[90915822594460]="Chrome Hearts Black Pink LS",[12852126150]="Chrome Hearts Miami Hoodie",[7369775838]="Chrome Hearts x LV Jacket",[18428381654]="Chrome Hearts Matty Boy Space",[11454813848]="Chrome Hearts Yellow Hoodie",[126863028392369]="Chrome Hearts Matty Boy Sweatshirt",[14127820316]="Chrome Hearts Cyan",[116987323218059]="Chrome Hearts Rainbow Sweatshirt",[6447552174]="Chrome Hearts Cyan Alt",[90412503682792]="Chrome Hearts Cross Patch Dog",[18400219191]="Chrome Hearts Zip Up Hoodie Black",[73657715280895]="Chrome Hearts Tee",[16582495088]="Chrome Hearts Basic Tee",[7381767636]="Chrome Hearts Orange Sweater",[77430172245334]="Chrome Hearts Red & Green Sweater",[92049531048374]="Chrome Hearts Sweats Black",[16430470279]="Chrome Hearts Multi Color Cargos",[85305185315542]="Chrome Hearts Rolling Stones",[79285824675024]="Chrome Hearts Ryft Davis",[122714934882673]="Chrome Hearts Grey Jeans",[10946069869]="Chrome Hearts Pink-Black Jeans",[15696366780]="Chrome Hearts Jeans",[7136404058]="Chrome Hearts Blue Jeans",[7548737358]="Chrome Hearts Orange Pants",[15167783027]="Chrome Hearts Red Jeans",[16733661152]="Chrome Hearts Gray Denim Jeans",[7902431231]="Chrome Hearts Blue Jeans Chrome",[7248675954]="Chrome Hearts X LV Jeans",[9026168986]="Chrome Hearts Red And Blue",[6488586232]="Moncler Vest Classic",[5341316038]="Moncler Gray Sweater",[6142390595]="Moncler Gray Vest",[6488509571]="Moncler Red Tracksuit Bottom",[4831711976]="Moncler TriColor Windbreaker",[6488495469]="Moncler Puffer Logo",[9375216039]="Moncler Black Jacket",[6455447834]="Moncler Red Puffer",[15338842173]="Moncler Black Tracksuit Bottom",[8446274549]="Moncler Parka Coat",[5964876806]="Moncler x Palm Angels Red Zip",[8165648360]="Moncler x Palm Angels Jacket",[6505230129]="Moncler Blue Zip-Up",[9384199616]="Moncler Blue Coat",[6787299892]="Moncler Maroon Jacket",[6505230940]="Moncler Green Zip-up",[3689506876]="Moncler Multi Colored Jacket",[13876237691]="Moncler x Palm Angels Black",[12636365073]="Moncler X PA Blue Tracksuit Bot",[12621049095]="Moncler X PA FG Tracksuit Bot",[6455445003]="Moncler Purple Bubble Jacket",[14396989921]="Moncler x PA Puffer Jacket",[5029449227]="Moncler Striped Technical",[11674658234]="Moncler Spider",[11484662835]="Moncler x PA Kelsey Puffer Blue",[13429337035]="Moncler x PA Fiber Light Puffer",[5459824253]="Moncler X PA Trackpants",[12621050787]="Moncler X PA Forest Green Bot",[105198371812252]="ERD White Long",[124798507529638]="ERD Destroyed Hoodie",[76738452087604]="ERD Longsleeve",[102885674981104]="ERD Blue Longsleeve",[128216714278616]="ERD Bully Hoodie",[120196252098729]="ERD Red Denim",[98881995294054]="ERD Archive Hoodie Red",[122273528955293]="ERD Archive Longsleeve",[137773512709519]="ERD Distressed Jeans v1",[83641705983017]="ERD Distressed Jeans v2",[74573745510706]="ERD x Rick Owens Jeans",[102019726797995]="ERD Red Jeans",[15570425245]="Raf Simons Hoodie",[75216977300015]="Raf Simons Brian Calvin Beer Girl",[125655994023355]="Raf Simons Christiane F Tees AW18",[76516442021518]="Raf Simons Polo Red",[91498176431445]="Raf Simons Black Christiane F AW18",[125538194046026]="Raf Simons Red Longsleeve",[122313792956641]="Raf Simons Brian Calvin Beer Girl Tee",[102589072483955]="Raf Simons Hoodie Gray",[86995497093030]="Raf Simons Bomber White",[140534031809179]="Raf Simons Red Longsleeve v2",[10443560347]="Raf Simons AW01 Runway",[95423048146621]="Raf Simons SS10 Sterling Ruby Shirt",[131319439176543]="Raf Simons Replicant Black",[124039750585318]="Raf Simons Ozweego 2 Khaki Gold",[87554525526000]="Raf Simons Ozweego Metallic Pink",[112685667527061]="Raf Simons Ozweego 3 Black Scarlett",[116642119535875]="Raf Simons Antei Purple",[72101896533425]="Raf Simons Ozweego 3 Bunny Cream",[76698897803837]="Raf Simons Ultrasceptre Black",[84478752542723]="Raf Simons Ozweego 2 Yellow Navy",[105222831634134]="Raf Simons Ozweego 2 Gray Green",[109462627025831]="Raf Simons Ozweego Replicant Green",[70728690346102]="Raf Simons Ozweego 2 Blue Red Lucora",[131686044597910]="Raf Simons Ozweego Replicant Brown",[101604148293803]="Raf Simons Pharaxus Green Black",[120612391944120]="Raf Simons 2-CB GHB Patchwork",[125293782853552]="Raf Simons LSD White",[75354435184240]="Raf Simons Cylon 21 Red",[18632819241]="Number(N)ine Brown Hoodie",[18632881209]="Number(N)ine Gray Hoodie",[105478169140045]="Number(N)ine Shield Gray Hoodie",[128716647842609]="Number(N)ine Red Longsleeve",[14885532636]="Number(N)ine T-Shirt",[12274864979]="Number(N)ine Black Longsleeve",[81231921426493]="Number(N)ine Zip Jacket",[99950858190570]="Number(N)ine Gray Zip Jacket",[17573405272]="Number(N)ine Gray Longsleeve",[81895753471926]="Number(N)ine Shield Black Hoodie",[18323948106]="Number(N)ine Black Jeans",[102839033215257]="Number(N)ine Distressed Jeans",[16949566103]="1017 ALYX 9SM Zip Jacket",[17508312490]="Vetements Anarchy",[11290616980]="Vetements Bomber Police",[89790335131378]="Vetements Bomber Green",[80547880319610]="Vetements T-Shirt Orange",[77439910826532]="Vetements Bomber Dark Green",[134508752165617]="Vetements Bomber",[128389783148999]="Vetements Zip-Hoodie",[117766762488194]="Vetements Bomber Red",[90919421530654]="Vetements T-Shirt Polizei",[77220484371723]="Vetements Clothing Green",[4552458072]="Vetements Antwerp Dark Red",[18720565335]="Vetements Antwerp Red",[124697147814478]="Vetements Antwerpen White v1",[75624653597148]="Vetements 204 Hyoma Raf Reconstructed",[15564674144]="Vetements Antwerpen White v2",[87891411586632]="Vetements Distressed Jeans",[132566833184808]="Vetements Sweatpants White",[80693415563613]="Vetements Sweatpants Black",[126970846706113]="Vetements Blue Distressed Jeans",[122468912421457]="Maison Margiela Belt Jacket",[73388686842934]="Maison Margiela Green Longsleeve",[135517402543302]="Maison Margiela Shirt",[137990594447175]="Maison Margiela Women's Fur Jacket",[81765716375958]="Maison Margiela Dark Jeans",[6763195401]="Goyard Green T-Shirt",[18370037060]="Dior T-Shirt",[101488585369119]="Dior Longsleeve",[18147277043]="Dior Sweatshirt",[122763783050786]="Dior Hoodie",[118344538644973]="Dior Sweater",[85583075418361]="Dior Zip Hoodie",[10371714775]="Dior Zip",[139013853108228]="Dior Jeans",[90433833342790]="Dior Shorts",[105804105689619]="Femboy Sweatshirt",[72870106856318]="Femboy Pants",[14141451141]="Delivery Kaif Backpack"}


local function extractId(t) if not t then return end return tonumber(tostring(t):match("(%d+)")) end
local function getId(model)
    if not model then return end
    local sh=model:FindFirstChildWhichIsA("Shirt",true)
    if sh then local id=extractId(sh.ShirtTemplate); if id then return id end end
    local pa=model:FindFirstChildWhichIsA("Pants",true)
    if pa then local id=extractId(pa.PantsTemplate); if id then return id end end
end

-- shared resolver worker: drains pendingQueue
local resolverActive=0
local function spawnResolver()
    if resolverActive>=6 then return end
    resolverActive=resolverActive+1
    task.spawn(function()
        while true do
            local id=table.remove(pendingQueue,1)
            if not id then break end
            local ok,info=pcall(function() return MPS:GetProductInfo(id,Enum.InfoType.Asset) end)
            if ok and info and info.Name and info.Name~="" and not looksLikeUuid(info.Name) then
                nameCache[id]=info.Name
            else nameCache[id]=false end
        end
        resolverActive=resolverActive-1
    end)
end
local function queueResolve(id)
    if not id then return end
    if nameCache[id]~=nil then return end
    -- check local DB first — instant, no marketplace call needed
    local dbName=ITEM_DB[id]
    if dbName then nameCache[id]=dbName return end
    nameCache[id]="PENDING"
    table.insert(pendingQueue,id)
    spawnResolver()
end

local function preloadAllNames()
    for _,zone in ipairs(Workspace:GetChildren()) do
        if zone.Name:match("^Shop_ShopZone_") then
            local items=zone:FindFirstChild("ItemSlots")
            if items then
                for _,slot in ipairs(items:GetChildren()) do
                    if slot.Name:match("^Slot_") then
                        queueResolve(getId(slot:FindFirstChild("Mannequin") or slot))
                    end
                end
            end
        end
    end
end

local function chromeColor(t)
    local TAU=6.2831853
    local r=0.86+0.14*math.sin(t)
    local g=0.86+0.14*math.sin(t+TAU/3)
    local b=0.86+0.14*math.sin(t+2*TAU/3)
    return Color3.new(math.clamp(r,0,1),math.clamp(g,0,1),math.clamp(b,0,1))
end

local function makeTag(adornee,source)
    local bb=Instance.new("BillboardGui")
    bb.Name="GC_ESP" bb.AlwaysOnTop=true bb.LightInfluence=0
    bb.Size=UDim2.fromOffset(S.BoxWidth,26)
    bb.StudsOffset=Vector3.new(0,3.2,0)
    bb.MaxDistance=math.huge bb.Adornee=adornee
    local frame=Instance.new("Frame",bb)
    frame.Size=UDim2.fromScale(1,1) frame.BackgroundColor3=Color3.new(0,0,0)
    frame.BackgroundTransparency=0.45 frame.BorderSizePixel=0
    local cr=Instance.new("UICorner",frame); cr.CornerRadius=UDim.new(0,6)
    local stroke=Instance.new("UIStroke",frame)
    stroke.Color=LEG_COLOR stroke.Thickness=1.2
    local nm=Instance.new("TextLabel",frame)
    nm.Size=UDim2.new(1,-6,1,0) nm.Position=UDim2.fromOffset(3,0)
    nm.BackgroundTransparency=1 nm.TextColor3=LEG_COLOR
    nm.Font=Enum.Font.GothamBold nm.TextSize=S.FontSize
    nm.TextXAlignment=Enum.TextXAlignment.Center nm.Text=""
    bb.Enabled=false bb.Parent=PG
    return {Gui=bb,Frame=frame,Stroke=stroke,NM=nm,
        Adornee=adornee,AssetId=nil,Source=source,RawName=nil,Resolved=false}
end

local function removeKey(k) local t=TAGS[k] if not t then return end if t.Gui then t.Gui:Destroy() end TAGS[k]=nil end
local function clearAll() for k in pairs(TAGS) do removeKey(k) end end

local function tagShop(slot)
    if TAGS[slot] then return false end
    local hl=slot:FindFirstChild("ItemHighlight",true) or slot:FindFirstChildWhichIsA("Highlight",true)
    if not hl or not isLegColor(hl.OutlineColor) then return false end
    local manny=slot:FindFirstChild("Mannequin")
    if not manny then return false end
    local hasCloth=manny:FindFirstChildWhichIsA("Shirt",true) or manny:FindFirstChildWhichIsA("Pants",true)
    if not hasCloth then return false end
    local part=manny.PrimaryPart or manny:FindFirstChildWhichIsA("BasePart")
        or hl.Adornee or slot:FindFirstChildWhichIsA("BasePart",true) or slot
    if not part then return false end
    local id=getId(manny)
    local tag=makeTag(part,"shop") tag.AssetId=id
    queueResolve(id)
    TAGS[slot]=tag return true
end

local function tagFloor(model)
    if TAGS[model] then return false end
    local ba=model:FindFirstChild("BillboardAnchor") if not ba then return false end
    local isLeg=false
    for _,d in ipairs(ba:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text and d.Text:lower():find("legend") then
            isLeg=true break end
    end
    if not isLeg then return false end
    local id=getId(model)
    if not id then return false end
    local tag=makeTag(ba,"floor") tag.AssetId=id
    queueResolve(id)
    TAGS[model]=tag return true
end

local function scanAll()
    local n=0
    for _,zone in ipairs(Workspace:GetChildren()) do
        if zone.Name:match("^Shop_ShopZone_") then
            local items=zone:FindFirstChild("ItemSlots")
            if items then
                for i,slot in ipairs(items:GetChildren()) do
                    if slot.Name:match("^Slot_") and tagShop(slot) then n=n+1 end
                    if (i%80)==0 then task.wait() end
                end
            end
        end
    end
    local dr=Workspace:FindFirstChild("DroppedItems")
    if dr then
        for _,m in ipairs(dr:GetChildren()) do
            if m:IsA("Model") and not Players:GetPlayerFromCharacter(m) and tagFloor(m) then n=n+1 end
        end
    end
    return n
end

local function unbind() for _,c in ipairs(CONNS) do c:Disconnect() end CONNS={} end
local function bindLive()
    local function bindDr(dr)
        table.insert(CONNS,dr.ChildAdded:Connect(function(c)
            if not S.On or not c:IsA("Model") then return end
            task.wait(0.3) tagFloor(c)
        end))
        table.insert(CONNS,dr.ChildRemoved:Connect(function(c) removeKey(c) end))
    end
    local dr=Workspace:FindFirstChild("DroppedItems")
    if dr then bindDr(dr) end
    table.insert(CONNS,Workspace.ChildAdded:Connect(function(c)
        if c.Name=="DroppedItems" then bindDr(c) end
    end))
end

local function getPlayerPos()
    local ch=LP.Character
    if ch then local hrp=ch:FindFirstChild("HumanoidRootPart") if hrp then return hrp.Position end end
    return Camera.CFrame.Position
end

--==================== HUD (отключён — без плавающей менюшки) ====================--

local renderConn
local function startRender()
    if renderConn then return end
    renderConn=RunService.RenderStepped:Connect(function()
        if not S.On then return end
        if S.Chrome then S.Color=chromeColor(tick()*0.9)
        else S.Color=S.PickedColor end

        local pos=getPlayerPos()
        local list={}
        local searchLow=S.Search:lower()
        local hasSearch=#searchLow>0

        for _,t in pairs(TAGS) do
            -- lazy resolve
            if t.AssetId and not t.Resolved then
                local n=nameCache[t.AssetId]
                if n==nil then queueResolve(t.AssetId)
                elseif type(n)=="string" and n~="PENDING" then t.Resolved=true t.RawName=n
                elseif n==false then t.Resolved=true end
            end
            -- match check
            local matched=false
            if hasSearch and t.RawName and t.RawName:lower():find(searchLow,1,true) then matched=true end
            t._matched=matched

            local d=999999 local show=true
            if t.Adornee and t.Adornee.Parent then
                d=(t.Adornee.Position-pos).Magnitude
                if d>S.MaxDist and not matched then show=false end
            else show=false end
            if hasSearch and S.MatchOnly and not matched then show=false end
            if show then t._d=d table.insert(list,t)
            elseif t.Gui then t.Gui.Enabled=false end
        end

        -- sort: matches first, then by distance
        table.sort(list, function(a,b)
            if a._matched~=b._matched then return a._matched end
            return a._d<b._d
        end)

        local cap=math.min(#list,S.MaxVisible)
        for i,t in ipairs(list) do
            -- always show matches even past cap
            if (i<=cap or t._matched) and t.Gui then
                t.Gui.Enabled=true
                local nm=t.RawName or "\xe2\x80\xa6"
                if #nm>22 then nm=nm:sub(1,21).."\xe2\x80\xa6" end
                local prefix=""
                if t._matched then prefix="\xe2\x96\xb6 " end
                t.NM.Text=prefix..nm.."  \xc2\xb7  "..math.floor(t._d).."m"
                t.NM.TextSize=S.FontSize
                if t._matched then
                    t.NM.TextColor3=Color3.fromRGB(0,255,140)
                    t.Stroke.Color=Color3.fromRGB(0,255,140)
                    t.Stroke.Thickness=2.2
                else
                    t.NM.TextColor3=S.Color
                    t.Stroke.Color=S.Color
                    t.Stroke.Thickness=1.2
                end
                t.Gui.Size=UDim2.fromOffset(S.BoxWidth,26)
                t.Frame.BackgroundTransparency=S.Transparency
            elseif t.Gui then t.Gui.Enabled=false end
        end
    end)
end
local function stopRender()
    if renderConn then renderConn:Disconnect() renderConn=nil end
    for _,t in pairs(TAGS) do if t.Gui then t.Gui.Enabled=false end end
end

local function start() S.On=true bindLive() startRender() scanAll() end
local function stop() S.On=false unbind() stopRender() clearAll() end
local function refresh() if not S.On then return end clearAll() scanAll() end




--==================== HvH ANTI-AIM (fun / visual) ====================--
-- Чистый визуал. Сервер в Роблоксе хитрег держит сам, от урона не спасёт.
local HVH = {
    On=false,
    YawIdx=1,         -- 1=Off 2=Static 3=Spin 4=Jitter 5=Random 6=Sway
    PitchIdx=1,       -- 1=Off 2=Up(Fake-Down) 3=Down 4=Zero 5=Fake(alt)
    StaticYaw=180,
    SpinSpeed=720,    -- deg/sec
    JitterAmt=180,
    Tilt=0,           -- deg
    Desync=false,     -- попытка визуального рассинхрона верх/низ
    BackTrack=false,  -- перс смотрит против движения
    FakeWalk=false,   -- жёст ходьбы в покое
}
local YAW_MODES = {"Off","Static","Spin","Jitter","Random","Sway"}
local PITCH_MODES = {"Off","Up","Down","Zero","Fake"}

local hvhConn, hvhCharAdded
local hvhStartTick = 0
local lastJitter = 1
local lastFakePitch = 1
local walkAnimTrack

local function getChar()
    local c = LP.Character
    if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    return c, hrp, hum
end

local function computeYaw(elapsed)
    local mode = YAW_MODES[HVH.YawIdx] or "Off"
    if mode == "Off" then return nil end
    if mode == "Static" then return math.rad(HVH.StaticYaw) end
    if mode == "Spin" then return math.rad((HVH.SpinSpeed * elapsed) % 360) end
    if mode == "Jitter" then
        local phase = math.floor(elapsed*15) % 2
        lastJitter = (phase == 0) and 1 or -1
        return math.rad(HVH.JitterAmt * lastJitter)
    end
    if mode == "Random" then
        if math.floor(elapsed*8) % 1 == 0 then end -- noop
        return math.rad(math.random(-180, 180))
    end
    if mode == "Sway" then
        return math.rad(math.sin(elapsed*3) * 180)
    end
    return nil
end

local function computePitch(elapsed)
    local mode = PITCH_MODES[HVH.PitchIdx] or "Off"
    if mode == "Off" then return 0 end
    if mode == "Up" then return math.rad(-89) end       -- в Roblox положительный X опускает нос вниз, инвертим
    if mode == "Down" then return math.rad(89) end
    if mode == "Zero" then return 0 end
    if mode == "Fake" then
        local phase = math.floor(elapsed*3) % 2
        return math.rad(phase == 0 and -89 or 89)
    end
    return 0
end

local function applyHvhChar()
    local c,_,hum = getChar()
    if not c then return end
    hum.AutoRotate = false
    -- Fake walk: просто пинаем WalkSpeed в 0 и играем анимацию (опционально)
end

local function startHvh()
    if hvhConn then return end
    HVH.On = true
    hvhStartTick = tick()
    applyHvhChar()
    hvhCharAdded = LP.CharacterAdded:Connect(function() task.wait(0.4) applyHvhChar() end)
    hvhConn = RunService.RenderStepped:Connect(function(dt)
        if not HVH.On then return end
        local c, hrp, hum = getChar()
        if not c then return end
        if hum.AutoRotate then hum.AutoRotate = false end

        local elapsed = tick() - hvhStartTick
        local yaw = computeYaw(elapsed)
        local pitch = computePitch(elapsed)
        local tilt = math.rad(HVH.Tilt or 0)

        -- BackTrack: если движемся — развернём на 180 от MoveDirection
        if HVH.BackTrack then
            local md = hum.MoveDirection
            if md.Magnitude > 0.1 then
                local angle = math.atan2(-md.X, -md.Z) -- look opposite
                yaw = (yaw or 0) + angle
            end
        end

        if yaw or pitch ~= 0 or tilt ~= 0 then
            local pos = hrp.Position
            local baseYaw = yaw or select(2, hrp.CFrame:ToOrientation())
            hrp.CFrame = CFrame.new(pos) * CFrame.Angles(pitch, baseYaw, tilt)
        end

        -- Desync: крутим верхнюю часть через Waist Motor6D
        if HVH.Desync then
            local torso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
            local waist = torso and (torso:FindFirstChild("Waist") or torso:FindFirstChild("Neck"))
            if waist and waist:IsA("Motor6D") then
                local off = math.sin(elapsed*12) * math.rad(60)
                waist.C0 = waist.C0 * CFrame.Angles(0, off*dt*5, 0)
            end
        end

        -- FakeWalk: принудительно WalkSpeed=16 но не двигаемся — роблокс сам включит аним, если хожубый
        -- (просто flag, без реальной имитации)
    end)
end

local function stopHvh()
        stopHesp()
    HVH.On = false
    if hvhConn then hvhConn:Disconnect() hvhConn = nil end
    if hvhCharAdded then hvhCharAdded:Disconnect() hvhCharAdded = nil end
    local _,_,hum = getChar()
    if hum then hum.AutoRotate = true end
end

local function cycleYaw()
    HVH.YawIdx = HVH.YawIdx % #YAW_MODES + 1
    return YAW_MODES[HVH.YawIdx]
end
local function cyclePitch()
    HVH.PitchIdx = HVH.PitchIdx % #PITCH_MODES + 1
    return PITCH_MODES[HVH.PitchIdx]
end

-- FUN PRESETS: однокнопочные выборы как в менюхах CS2
local function presetFun()
    HVH.YawIdx = 4; HVH.JitterAmt = 180
    HVH.PitchIdx = 5
    HVH.Tilt = 0
    HVH.BackTrack = true
    HVH.Desync = true
end
local function presetSpin()
    HVH.YawIdx = 3; HVH.SpinSpeed = 1440
    HVH.PitchIdx = 2
    HVH.Tilt = 0
    HVH.BackTrack = false
    HVH.Desync = false
end
local function presetLegit()
    HVH.YawIdx = 2; HVH.StaticYaw = 180
    HVH.PitchIdx = 4
    HVH.Tilt = 0
    HVH.BackTrack = false
    HVH.Desync = false
end
local function presetRetard()
    HVH.YawIdx = 5
    HVH.PitchIdx = 5
    HVH.Tilt = 45
    HVH.BackTrack = true
    HVH.Desync = true
end
--==================== END HvH ====================--


--==================== HvH ESP (CS:GO style, Drawing API)  v2 clean ====================--
local HESP = {
    On=false,
    Skeleton=false,
    ChamsColor=Color3.fromRGB(255,60,60), -- legacy name; used as global ESP color (box/tracer/HP outline)
    Watermark=false,
    HitMarker=false,
    SpecList=false,
    HealthBar=false,
    Tracers=false,
    TracerOrigin="Bottom", -- Bottom | Mouse | Top
    MaxDist=2000,
}

-- runtime state
local hespConn         -- RenderStepped connection
local hespPlrRem       -- PlayerRemoving connection (single, owned)
local drawMap   = {}   -- [Player] = {box,boxOutline,name,dist,hpBg,hp,snap,skel={...}}
local hitLines  = {}
local watermark, watermarkBg
local specTexts = {}
local lastHpMap = {}
local lastHitTick = 0

-- fps avg (no Wait() inside render loop!)
local _fpsLast, _fpsAvg = tick(), 60

local R15_BONES = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local R6_BONES = {
    {"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},
    {"Torso","Left Leg"},{"Torso","Right Leg"},
}
local SKEL_SLOTS = 14  -- enough for R15

local function getBones(char)
    if char:FindFirstChild("UpperTorso") then return R15_BONES, #R15_BONES end
    if char:FindFirstChild("Torso")      then return R6_BONES,  #R6_BONES  end
    return nil, 0
end

local hasDrawing = (typeof and typeof(Drawing) == "table") or (type(Drawing) == "table" or type(Drawing) == "userdata")

local function safeNew(kind, props)
    if not hasDrawing then return nil end
    local ok, d = pcall(Drawing.new, kind)
    if not ok or not d then return nil end
    for k,v in pairs(props) do pcall(function() d[k] = v end) end
    return d
end

local function safeRemove(obj)
    if obj then pcall(function() obj:Remove() end) end
end
local function safeHide(obj)
    if obj then pcall(function() obj.Visible = false end) end
end

-- ---------------- per-player drawing object pool ----------------
local function acquire(plr)
    local d = drawMap[plr]
    if d then return d end
    d = {}
    d.boxOutline = safeNew("Square", {Thickness=3, Color=Color3.new(0,0,0),  Filled=false, Transparency=1, Visible=false, ZIndex=1})
    d.box        = safeNew("Square", {Thickness=1, Color=Color3.fromRGB(255,255,255), Filled=false, Transparency=1, Visible=false, ZIndex=2})
    d.hpBg       = safeNew("Square", {Thickness=0, Color=Color3.new(0,0,0),  Filled=true,  Transparency=1, Visible=false, ZIndex=1})
    d.hp         = safeNew("Square", {Thickness=0, Color=Color3.fromRGB(0,255,0), Filled=true, Transparency=1, Visible=false, ZIndex=2})
    d.name       = safeNew("Text",   {Size=13, Center=true,  Outline=true, Color=Color3.new(1,1,1), OutlineColor=Color3.new(0,0,0), Visible=false, Font=2, ZIndex=3})
    d.dist       = safeNew("Text",   {Size=12, Center=true,  Outline=true, Color=Color3.fromRGB(220,220,220), OutlineColor=Color3.new(0,0,0), Visible=false, Font=2, ZIndex=3})
    d.snap       = safeNew("Line",   {Thickness=1, Color=Color3.new(1,1,1), Transparency=1, Visible=false, ZIndex=1})
    d.skel = {}
    for i=1,SKEL_SLOTS do
        d.skel[i] = safeNew("Line", {Thickness=1, Color=Color3.new(1,1,1), Transparency=1, Visible=false, ZIndex=2})
    end
    drawMap[plr] = d
    return d
end

local function hideAll(d)
    if not d then return end
    safeHide(d.box); safeHide(d.boxOutline)
    safeHide(d.hpBg); safeHide(d.hp)
    safeHide(d.name); safeHide(d.dist); safeHide(d.snap)
    for i=1,#d.skel do safeHide(d.skel[i]) end
end

local function release(plr)
    local d = drawMap[plr]
    if d then
        safeRemove(d.box); safeRemove(d.boxOutline)
        safeRemove(d.hpBg); safeRemove(d.hp)
        safeRemove(d.name); safeRemove(d.dist); safeRemove(d.snap)
        for i=1,#d.skel do safeRemove(d.skel[i]) end
        drawMap[plr] = nil
    end
    lastHpMap[plr] = nil
end

local function hpColor(pct)
    pct = math.clamp(pct, 0, 1)
    if pct > 0.5 then
        return Color3.fromRGB(math.floor((1-pct)*2*255), 255, 0)
    end
    return Color3.fromRGB(255, math.floor(pct*2*255), 0)
end

-- ---------------- bbox жёстко якорен к HumanoidRootPart ----------------
-- НИКОГДА не используем char:GetBoundingBox() — в играх вроде TSUM персонажи
-- имеют прикреплённые эффекты/ауры/оружие на 100+ студов, и центр bbox
-- уезжает далеко от реального игрока → бокс растягивается на пол-экрана. HRP всегда
-- в центре хуманоида, не зависит от аксессуаров.
local function getScreenBox(char, hrp)
    -- Build a WORLD-AXIS-ALIGNED bbox around HRP center.
    -- Using cf:ToWorldSpace with local offsets rotates the box with the character
    -- and makes a lying/tilted rig project to a hugely-stretched 2D rect. World-axis
    -- offsets keep the bbox stable regardless of character orientation.
    local center = hrp.Position
    local isR15  = char:FindFirstChild("UpperTorso") ~= nil
    local size   = isR15 and Vector3.new(4, 6, 2.5) or Vector3.new(4, 5, 2.5)
    local sx, sy, sz = size.X * 0.5, size.Y * 0.5, size.Z * 0.5

    local vp = Camera.ViewportSize
    -- Hard distance guards: too close = projection explodes; too far = irrelevant.
    local dist = (Camera.CFrame.Position - center).Magnitude
    if dist < 3 then return nil end

    local minX, minY =  math.huge,  math.huge
    local maxX, maxY = -math.huge, -math.huge

    -- Require ALL 8 corners to be safely in front of the camera (Z >= 5 studs).
    -- This avoids the partial-behind-camera projection blow-up that produces the
    -- half-screen floating box.
    for ix = -1, 1, 2 do for iy = -1, 1, 2 do for iz = -1, 1, 2 do
        local world = center + Vector3.new(sx*ix, sy*iy, sz*iz)
        local pt = Camera:WorldToViewportPoint(world)
        if pt.Z < 5 then return nil end
        if pt.X < minX then minX = pt.X end
        if pt.X > maxX then maxX = pt.X end
        if pt.Y < minY then minY = pt.Y end
        if pt.Y > maxY then maxY = pt.Y end
    end end end

    local w = maxX - minX
    local h = maxY - minY
    if w <= 0 or h <= 0 then return nil end

    -- HARD CAPS: a humanoid bbox can never be larger than the screen itself.
    -- These catch any pathological projection that slipped past the Z guard.
    if h > vp.Y * 0.85 then return nil end
    if w > vp.X * 0.55 then return nil end

    -- Expected on-screen height from FOV. Real bbox shouldn't exceed 2.2x expected.
    local fovRad    = math.rad(Camera.FieldOfView or 70)
    local expectedH = (size.Y * vp.Y) / (2 * dist * math.tan(fovRad * 0.5))
    if expectedH > 0 and h > expectedH * 2.2 then return nil end
    if expectedH > 0 and w > expectedH * 2.2 then return nil end

    -- Reject entirely-off-screen boxes early.
    if maxX < 0 or minX > vp.X then return nil end
    if maxY < 0 or minY > vp.Y then return nil end

    -- Clamp to viewport (no negative coords, no overflow). Drawing API handles partials.
    minX = math.max(0, math.floor(minX))
    minY = math.max(0, math.floor(minY))
    maxX = math.min(vp.X, math.ceil(maxX))
    maxY = math.min(vp.Y, math.ceil(maxY))
    return minX, minY, maxX, maxY
end

-- ---------------- watermark ----------------
local function ensureWatermark()
    if watermark then return end
    watermarkBg = safeNew("Square", {Thickness=0, Color=Color3.new(0,0,0), Filled=true, Transparency=0.55, Visible=false, ZIndex=998})
    watermark   = safeNew("Text",   {Size=13, Center=false, Outline=true, Color=Color3.new(1,1,1), OutlineColor=Color3.new(0,0,0), Font=2, Visible=false, ZIndex=999})
end

local function updateWatermark(dt)
    if not watermark then return end
    -- moving avg FPS without yielding
    if dt and dt > 0 then
        _fpsAvg = _fpsAvg * 0.9 + (1/dt) * 0.1
    end
    local ping = 0
    pcall(function()
        local s = Stats and Stats.Network and Stats.Network.ServerStatsItem and Stats.Network.ServerStatsItem["Data Ping"]
        if s then ping = math.floor(s:GetValue()) end
    end)
    local txt = string.format("Fekality  |  %s  |  %d fps  |  %d ms", LP.Name or "?", math.floor(_fpsAvg), ping)
    watermark.Text = txt
    local bounds = watermark.TextBounds
    if not bounds or bounds.X == 0 then bounds = Vector2.new(#txt * 7, 14) end
    local vp = Camera.ViewportSize
    local pad = 6
    local x = vp.X - bounds.X - pad*2 - 10
    watermark.Position = Vector2.new(x + pad, 10 + pad)
    watermark.Color    = HESP.ChamsColor
    watermark.Visible  = true
    if watermarkBg then
        watermarkBg.Size = Vector2.new(bounds.X + pad*2, bounds.Y + pad*2)
        watermarkBg.Position = Vector2.new(x, 10)
        watermarkBg.Visible = true
    end
end

-- ---------------- hit marker ----------------
local function ensureHitMarker()
    if #hitLines > 0 then return end
    for i=1,4 do
        hitLines[i] = safeNew("Line", {Thickness=2, Color=Color3.fromRGB(255,255,255), Transparency=1, Visible=false, ZIndex=997})
    end
end

local function flashHit() lastHitTick = tick() end

local function updateHitMarker()
    local alive = tick() - lastHitTick
    if alive < 0 or alive > 0.35 then
        for i=1,#hitLines do safeHide(hitLines[i]) end
        return
    end
    local m = UIS:GetMouseLocation()
    local cx, cy = m.X, m.Y
    local s, g = 6, 2
    local trans = math.clamp(1 - alive/0.35, 0, 1)
    local cfg = {
        {Vector2.new(cx-s-g, cy-s-g), Vector2.new(cx-g,   cy-g)},
        {Vector2.new(cx+g,   cy-g),   Vector2.new(cx+s+g, cy-s-g)},
        {Vector2.new(cx-s-g, cy+s+g), Vector2.new(cx-g,   cy+g)},
        {Vector2.new(cx+g,   cy+g),   Vector2.new(cx+s+g, cy+s+g)},
    }
    for i,l in ipairs(hitLines) do
        if l then
            l.From, l.To = cfg[i][1], cfg[i][2]
            l.Transparency = trans
            l.Visible = true
        end
    end
end

-- ---------------- spectator / player list ----------------
-- Roblox не даёт API "кто спекает" (Camera локальный). Поэтому показываем
-- список всех игроков с индикаторами: ● ALIVE / ● DEAD / ● LOBBY (= вероятный спек).
local specHeader
local function updateSpecList()
    local rows = {}
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local ch  = p.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            local status, col
            if not ch then
                status, col = "LOBBY", Color3.fromRGB(180,180,180)
            elseif (not hum) or hum.Health <= 0 then
                status, col = "DEAD",  Color3.fromRGB(255,80,80)
            else
                status, col = "ALIVE", Color3.fromRGB(120,255,120)
            end
            rows[#rows+1] = { name = p.Name, status = status, color = col }
        end
    end

    if not specHeader then
        specHeader = safeNew("Text", {Size=13, Center=false, Outline=true, Color=Color3.new(1,1,1), OutlineColor=Color3.new(0,0,0), Font=2, Visible=false, ZIndex=997})
    end

    while #specTexts < #rows do
        specTexts[#specTexts+1] = safeNew("Text", {Size=12, Center=false, Outline=true, Color=Color3.new(1,1,1), OutlineColor=Color3.new(0,0,0), Font=2, Visible=false, ZIndex=996})
    end

    local vp = Camera.ViewportSize
    local rightX = vp.X - 180   -- фиксированная анкор-позиция справа (не зависим от TextBounds)
    if rightX < 50 then rightX = 50 end
    local y = 80

    if specHeader then
        specHeader.Text = string.format("Players (%d)", #rows)
        specHeader.Position = Vector2.new(rightX, y)
        specHeader.Color = HESP.ChamsColor
        specHeader.Visible = true
        y = y + 18
    end

    for i,t in ipairs(specTexts) do
        if i <= #rows and t then
            local r = rows[i]
            t.Text = string.format("[%s] %s", r.status, r.name)
            t.Position = Vector2.new(rightX, y)
            t.Color = r.color
            t.Visible = true
            y = y + 15
        elseif t then
            t.Visible = false
        end
    end
end

local function hideSpecList()
    if specHeader then specHeader.Visible = false end
    for i=1,#specTexts do safeHide(specTexts[i]) end
end

-- ---------------- per-player update (all in pcall at caller) ----------------
local function updatePlayer(plr, lpRoot)
    local d = drawMap[plr] or acquire(plr)
    if not d or not d.box then return end

    local char = plr.Character
    if not char or not char.Parent then
        hideAll(d); return
    end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local hrp  = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if (not hum) or (hum.Health <= 0) or (not hrp) then
        hideAll(d); return
    end

    -- hit-detection proxy
    local prev = lastHpMap[plr]
    if prev and hum.Health < prev - 0.5 and HESP.HitMarker then flashHit() end
    lastHpMap[plr] = hum.Health

    -- distance gate
    local dist = lpRoot and (lpRoot.Position - hrp.Position).Magnitude or 0
    if dist > HESP.MaxDist then
        hideAll(d); return
    end

    local minX, minY, maxX, maxY = getScreenBox(char, hrp)
    if not minX then hideAll(d); return end
    local w = maxX - minX
    local h = maxY - minY
    if w < 2 or h < 2 then hideAll(d); return end

    -- clamp drawing rect into screen with margin so Drawing API doesn't choke
    local vp = Camera.ViewportSize
    local clX = math.max(-20, math.min(minX, vp.X + 20))
    local clY = math.max(-20, math.min(minY, vp.Y + 20))
    local clW = math.max(2, math.min(w, vp.X + 40))
    local clH = math.max(2, math.min(h, vp.Y + 40))

    -- 2D box
    d.boxOutline.Size     = Vector2.new(clW, clH)
    d.boxOutline.Position = Vector2.new(clX, clY)
    d.boxOutline.Visible  = true
    d.box.Size            = Vector2.new(clW, clH)
    d.box.Position        = Vector2.new(clX, clY)
    d.box.Color           = HESP.ChamsColor
    d.box.Visible         = true

    -- name
    local nm = plr.DisplayName
    if nm == nil or nm == "" then nm = plr.Name end
    d.name.Text     = nm
    d.name.Position = Vector2.new(clX + clW*0.5, clY - 16)
    d.name.Visible  = true

    -- distance
    local dTxt
    if dist >= 1000 then dTxt = string.format("[%.1fk]", dist/1000)
    else dTxt = string.format("[%dm]", math.floor(dist)) end
    d.dist.Text     = dTxt
    d.dist.Position = Vector2.new(clX + clW*0.5, clY + clH + 2)
    d.dist.Visible  = true

    -- hp bar
    if HESP.HealthBar then
        local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
        local bw = 3
        d.hpBg.Size     = Vector2.new(bw+2, clH+2)
        d.hpBg.Position = Vector2.new(clX - bw - 5, clY - 1)
        d.hpBg.Visible  = true
        d.hp.Size       = Vector2.new(bw, clH * pct)
        d.hp.Position   = Vector2.new(clX - bw - 4, clY + clH*(1-pct))
        d.hp.Color      = hpColor(pct)
        d.hp.Visible    = true
    else
        d.hpBg.Visible = false
        d.hp.Visible   = false
    end

    -- tracer
    if HESP.Tracers then
        local ox, oy
        if HESP.TracerOrigin == "Top" then
            ox, oy = vp.X*0.5, 0
        elseif HESP.TracerOrigin == "Mouse" then
            local m = UIS:GetMouseLocation(); ox, oy = m.X, m.Y
        else
            ox, oy = vp.X*0.5, vp.Y
        end
        d.snap.From    = Vector2.new(ox, oy)
        d.snap.To      = Vector2.new(clX + clW*0.5, clY + clH)
        d.snap.Color   = HESP.ChamsColor
        d.snap.Visible = true
    else
        d.snap.Visible = false
    end

    -- skeleton
    if HESP.Skeleton then
        local bones, cnt = getBones(char)
        if bones then
            for i=1,SKEL_SLOTS do d.skel[i].Visible = false end
            for i=1,cnt do
                local a = char:FindFirstChild(bones[i][1])
                local b = char:FindFirstChild(bones[i][2])
                local ln = d.skel[i]
                if a and b and ln then
                    local ap = Camera:WorldToViewportPoint(a.Position)
                    local bp = Camera:WorldToViewportPoint(b.Position)
                    if ap.Z > 0 and bp.Z > 0 then
                        ln.From = Vector2.new(ap.X, ap.Y)
                        ln.To   = Vector2.new(bp.X, bp.Y)
                        ln.Visible = true
                    else
                        ln.Visible = false
                    end
                end
            end
        end
    else
        for i=1,SKEL_SLOTS do d.skel[i].Visible = false end
    end
end

-- ---------------- start / stop ----------------
local function stopHesp()
    HESP.On = false
    if hespConn   then hespConn:Disconnect();   hespConn   = nil end
    if hespPlrRem then hespPlrRem:Disconnect(); hespPlrRem = nil end
    for plr,_ in pairs(drawMap)  do release(plr) end
    drawMap, lastHpMap = {}, {}
    if watermark   then safeRemove(watermark);   watermark   = nil end
    if watermarkBg then safeRemove(watermarkBg); watermarkBg = nil end
    for i=1,#hitLines  do safeRemove(hitLines[i]) end ; hitLines  = {}
    for i=1,#specTexts do safeRemove(specTexts[i]) end ; specTexts = {}
    if specHeader then safeRemove(specHeader); specHeader = nil end
end

local function startHesp()
    if hespConn then return end
    if not hasDrawing then
        warn("[Fekality] Drawing API not available on this executor — ESP disabled.")
        return
    end
    HESP.On = true
    _fpsLast = tick()

    hespPlrRem = Players.PlayerRemoving:Connect(function(p) release(p) end)

    hespConn = RunService.RenderStepped:Connect(function(dt)
        if not HESP.On then return end
        local now = tick()
        if dt == nil or dt <= 0 then dt = math.max(now - _fpsLast, 1/240) end
        _fpsLast = now

        -- cached local-player root
        local lpChar = LP.Character
        local lpRoot = lpChar and (lpChar:FindFirstChild("HumanoidRootPart") or lpChar:FindFirstChild("Torso"))

        for _,plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then
                local ok, err = pcall(updatePlayer, plr, lpRoot)
                if not ok then
                    -- never let one bad player kill the whole loop
                    -- (silently swallow; release on PlayerRemoving will clean up)
                end
            end
        end

        if HESP.Watermark then ensureWatermark(); pcall(updateWatermark, dt)
        else
            if watermark   then watermark.Visible   = false end
            if watermarkBg then watermarkBg.Visible = false end
        end

        if HESP.HitMarker then ensureHitMarker(); pcall(updateHitMarker)
        else for i=1,#hitLines do safeHide(hitLines[i]) end end

        if HESP.SpecList then pcall(updateSpecList) else hideSpecList() end
    end)
end
--==================== END HvH ESP ====================--

task.spawn(preloadAllNames)


--==================== draggable helper ====================--
local function makeDraggable(handle, target)
    local dragging,dragStart,startPos=false,nil,nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1
        or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true dragStart=input.Position startPos=target.Position
            input.Changed:Connect(function()
                if input.UserInputState==Enum.UserInputState.End then dragging=false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType==Enum.UserInputType.MouseMovement
        or input.UserInputType==Enum.UserInputType.Touch then
            local d=input.Position-dragStart
            target.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,
                                     startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end)
end
--==================== Fatality UI ====================--
local _TextSvc = game:GetService("TextService")
local Window = Fatality.new({ Name = "Fekality", Expire = "never" })

-- ===== title fit fix =====
task.spawn(function()
    local CG = (gethui and gethui()) or game:GetService("CoreGui")
    local target = "Fekality"
    local done = false
    for _ = 1, 80 do
        if done then return end
        task.wait(0.1)
        local ok, desc = pcall(function() return CG:GetDescendants() end)
        if ok and desc then
            for _, d in ipairs(desc) do
                if d:IsA("TextLabel") and d.Text == target then
                    pcall(function()
                        d.TextScaled       = false
                        d.TextTruncate     = Enum.TextTruncate.None
                        d.TextWrapped      = false
                        d.ClipsDescendants = false
                        d.TextXAlignment   = Enum.TextXAlignment.Left
                        if d.Parent and d.Parent:IsA("GuiObject") then
                            d.Size = UDim2.new(1, -4, d.Size.Y.Scale, d.Size.Y.Offset)
                        end
                        local maxW = math.max(d.AbsoluteSize.X, 110)
                        local startSz = (d.TextSize and d.TextSize > 0) and d.TextSize or 14
                        for sz = startSz, 8, -1 do
                            d.TextSize = sz
                            local ok2, b = pcall(function()
                                return _TextSvc:GetTextSize(target, sz, d.Font, Vector2.new(9999, 9999))
                            end)
                            if ok2 and b and b.X <= maxW - 4 then break end
                        end
                    end)
                    done = true
                    break
                end
            end
        end
    end
end)
if Notifier then
    pcall(function()
        Notifier:Notify({ Title = "Fekality", Content = "loaded for "..LP.Name, Icon = "check" })
    end)
end

local EspMenu    = Window:AddMenu({ Name = "ESP",    Icon = "eye"      })
local SearchMenu = Window:AddMenu({ Name = "SEARCH", Icon = "search"   })
local LookMenu   = Window:AddMenu({ Name = "LOOK",   Icon = "target"   })
local HvhMenu    = Window:AddMenu({ Name = "HVH",    Icon = "skull"    })
local InfoMenu   = Window:AddMenu({ Name = "INFO",   Icon = "info"     })

-- ============ ESP tab ============
local MainSec    = EspMenu:AddSection({ Name = "MAIN",    Position = "left"   })
local RangeSec   = EspMenu:AddSection({ Name = "RANGE",   Position = "center" })
local ActionsSec = EspMenu:AddSection({ Name = "ACTIONS", Position = "right"  })

MainSec:AddToggle({ Name = "Enable ESP", Default = false,
    Callback = function(v) if v then start() else stop() end end })

RangeSec:AddSlider({ Name = "Max distance", Min = 30, Max = 500, Default = 180, Type = " m",
    Callback = function(v) S.MaxDist = math.floor(v) end })
RangeSec:AddSlider({ Name = "Max labels", Min = 3, Max = 80, Default = 25,
    Callback = function(v) S.MaxVisible = math.floor(v) end })

ActionsSec:AddButton({ Name = "Rescan", Callback = refresh })
ActionsSec:AddButton({ Name = "Unload", Callback = function()
    stop()
    for _,g in ipairs(PG:GetChildren()) do if g.Name == "GC_ESP" then g:Destroy() end end
end })

-- ============ SEARCH tab ============
local SearchSec = SearchMenu:AddSection({ Name = "FIND ITEM", Position = "left" })
SearchSec:AddToggle({ Name = "Show only matches", Default = false,
    Callback = function(v) S.MatchOnly = v end })

-- preset filter list — quick categories instead of free-text
SearchSec:AddDropdown({
    Name = "Filter",
    Values = { "", "balenciaga", "gucci", "prada", "chanel", "dior", "louis", "rick", "raf", "yeezy" },
    Default = "",
    Callback = function(v) S.Search = v or "" end,
})

-- ============ LOOK tab ============
local LookSec  = LookMenu:AddSection({ Name = "BOX",   Position = "left"   })
local ColorSec = LookMenu:AddSection({ Name = "COLOR", Position = "center" })

LookSec:AddSlider({ Name = "Box width", Min = 80, Max = 260, Default = 130, Type = " px",
    Callback = function(v) S.BoxWidth = math.floor(v) end })
LookSec:AddSlider({ Name = "Font size", Min = 9, Max = 22, Default = 12, Type = " px",
    Callback = function(v) S.FontSize = math.floor(v) end })
LookSec:AddSlider({ Name = "Transparency", Min = 0, Max = 100, Default = 45, Type = "%",
    Callback = function(v) S.Transparency = v/100 end })

ColorSec:AddToggle({ Name = "Chrome shimmer", Default = true,
    Callback = function(v) S.Chrome = v end })
ColorSec:AddColorPicker({ Name = "Custom color", Default = Color3.fromRGB(255,215,0),
    Callback = function(c) S.PickedColor = c end })

-- ============ HVH tab ============
local HvhMain    = HvhMenu:AddSection({ Name = "ANTI-AIM", Position = "left"   })
local HespSec    = HvhMenu:AddSection({ Name = "ESP",      Position = "center" })
local TracerSec  = HvhMenu:AddSection({ Name = "TRACERS",  Position = "right"  })
local HvhPresets = HvhMenu:AddSection({ Name = "PRESETS",  Position = "right"  })

HvhMain:AddToggle({ Name = "Enable HvH", Default = false, Risky = true,
    Callback = function(v) if v then startHvh() else stopHvh() end end })

HvhMain:AddDropdown({ Name = "Yaw mode", Values = YAW_MODES, Default = "Off",
    Callback = function(v)
        for i,m in ipairs(YAW_MODES) do if m == v then HVH.YawIdx = i break end end
    end })
HvhMain:AddDropdown({ Name = "Pitch mode", Values = PITCH_MODES, Default = "Off",
    Callback = function(v)
        for i,m in ipairs(PITCH_MODES) do if m == v then HVH.PitchIdx = i break end end
    end })

HvhMain:AddSlider({ Name = "Static Yaw", Min = -180, Max = 180, Default = 180, Type = "°",
    Callback = function(v) HVH.StaticYaw = v end })
HvhMain:AddSlider({ Name = "Spin Speed", Min = 90, Max = 3600, Default = 720, Type = "°/s",
    Callback = function(v) HVH.SpinSpeed = v end })
HvhMain:AddSlider({ Name = "Jitter Amount", Min = 10, Max = 180, Default = 180, Type = "°",
    Callback = function(v) HVH.JitterAmt = v end })
HvhMain:AddSlider({ Name = "Body Tilt", Min = -90, Max = 90, Default = 0, Type = "°",
    Callback = function(v) HVH.Tilt = v end })
HvhMain:AddToggle({ Name = "Desync (upper)", Default = false,
    Callback = function(v) HVH.Desync = v end })
HvhMain:AddToggle({ Name = "BackTrack walk", Default = false,
    Callback = function(v) HVH.BackTrack = v end })

HespSec:AddToggle({ Name = "Enable HvH ESP", Default = false,
    Callback = function(v) if v then startHesp() else stopHesp() end end })
HespSec:AddToggle({ Name = "Skeleton", Default = false,
    Callback = function(v) HESP.Skeleton = v end })
HespSec:AddColorPicker({ Name = "ESP color", Default = Color3.fromRGB(255,60,60),
    Callback = function(c) HESP.ChamsColor = c end })
HespSec:AddToggle({ Name = "Health bars", Default = false,
    Callback = function(v) HESP.HealthBar = v end })
HespSec:AddToggle({ Name = "Hit marker", Default = false,
    Callback = function(v) HESP.HitMarker = v end })
HespSec:AddToggle({ Name = "Watermark", Default = false,
    Callback = function(v) HESP.Watermark = v end })
HespSec:AddToggle({ Name = "Spectator list", Default = false,
    Callback = function(v) HESP.SpecList = v end })
HespSec:AddSlider({ Name = "Max distance", Min = 50, Max = 5000, Default = 2000, Type = " studs",
    Callback = function(v) HESP.MaxDist = v end })

TracerSec:AddToggle({ Name = "Enable tracers", Default = false,
    Callback = function(v) HESP.Tracers = v end })
TracerSec:AddDropdown({ Name = "Origin", Values = { "Bottom", "Top", "Mouse" }, Default = "Bottom",
    Callback = function(v) HESP.TracerOrigin = v end })

HvhPresets:AddButton({ Name = "Legit",   Callback = function() presetLegit()   end })
HvhPresets:AddButton({ Name = "Spin",    Callback = function() presetSpin()    end })
HvhPresets:AddButton({ Name = "Fun",     Callback = function() presetFun()     end })
HvhPresets:AddButton({ Name = "Retard",  Callback = function() presetRetard()  end })

-- ============ INFO tab ============
local PrivacySec = InfoMenu:AddSection({ Name = "PRIVACY", Position = "left" })
PrivacySec:AddToggle({ Name = "Hide nickname", Default = true,
    Callback = function(v) NICK.Hide = v; applyNickHide() end })

local AboutSec = InfoMenu:AddSection({ Name = "ABOUT", Position = "center" })
AboutSec:AddButton({ Name = "Fekality v5.1", Callback = function()
    if Notifier then pcall(function()
        Notifier:Notify({ Title = "Fekality", Content = "v4.5 · Fatality UI", Icon = "info" })
    end) end
end })
