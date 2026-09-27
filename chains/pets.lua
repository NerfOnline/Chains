-- Beastmaster jug pets and Puppetmaster automaton frames.
-- Jugs are keyed by the pet's name and list the Ready moves that skillchain.

local pets = {};

pets.jugs = {
    SheepFamiliar = {
        [3857] = true, -- Lamb Chop
        [3859] = true, -- Sheep Charge
    },
    HareFamiliar = {
        [3840] = true, -- Foot Kick
        [3842] = true, -- Whirl Claws
    },
    CrabFamiliar = {
        [3863] = true, -- Big Scissors
    },
    CourierCarrie = {
        [3863] = true, -- Big Scissors
    },
    Homunculus = {
        [3843] = true, -- Head Butt
        [3845] = true, -- Wild Oats
        [3846] = true, -- Leaf Dagger
    },
    TigerFamiliar = {
        [3849] = true, -- Razor Fang
        [3850] = true, -- Claw Cyclone
        [3959] = true, -- Crossthrash
    },
    FlowerpotBill = {
        [3843] = true, -- Head Butt
        [3845] = true, -- Wild Oats
        [3846] = true, -- Leaf Dagger
    },
    EftFamiliar = {
        [3891] = true, -- Nimble Snap
        [3892] = true, -- Cyclotail
    },
    LizardFamiliar = {
        [3851] = true, -- Tail Blow
        [3853] = true, -- Blockhead
        [3854] = true, -- Brain Crush
    },
    MayflyFamiliar = {
        [3938] = true, -- Somersault
    },
    FunguarFamiliar = {
        [3868] = true, -- Frogkick
    },
    BeetleFamiliar = {
        [3875] = true, -- Power Attack
        [3877] = true, -- Rhino Attack
    },
    AntlionFamiliar = {
        [3885] = true, -- Mandibular Bite
    },
    MiteFamiliar = {
        [3894] = true, -- Double Claw
        [3895] = true, -- Grapple
        [3897] = true, -- Spinning Top
    },
    LullabyMelodia = {
        [3857] = true, -- Lamb Chop
        [3859] = true, -- Sheep Charge
    },
    KeenearedSteffi = {
        [3840] = true, -- Foot Kick
        [3842] = true, -- Whirl Claws
    },
    FlowerpotBen = {
        [3843] = true, -- Head Butt
        [3845] = true, -- Wild Oats
        [3846] = true, -- Leaf Dagger
    },
    SaberSiravarde = {
        [3849] = true, -- Razor Fang
        [3850] = true, -- Claw Cyclone
        [3959] = true, -- Crossthrash
    },
    ColdbloodComo = {
        [3851] = true, -- Tail Blow
        [3853] = true, -- Blockhead
        [3854] = true, -- Brain Crush
    },
    ShellbusterOrob = {
        [3938] = true, -- Somersault
    },
    AmbusherAllie = {
        [3891] = true, -- Nimble Snap
        [3892] = true, -- Cyclotail
    },
    LifedrinkerLars = {
        [3894] = true, -- Double Claw
        [3895] = true, -- Grapple
        [3897] = true, -- Spinning Top
    },
    PanzerGalahad = {
        [3875] = true, -- Power Attack
        [3877] = true, -- Rhino Attack
    },
    ChopsueyChucky = {
        [3885] = true, -- Mandibular Bite
    },
    AmigoSabotender = {
        [3866] = true, -- Needleshot
        [3867] = true, -- Random Needles
    },
    LuckyLulush = {
        [3840] = true, -- Foot Kick
        [3842] = true, -- Whirl Claws
    },
    FatsoFargann = {
        [3900] = true, -- Suction
    },
    DiscreetLouise = {
        [3868] = true, -- Frogkick
    },
    SwiftSieghard = {
        [3909] = true, -- Scythe Tail
        [3910] = true, -- Ripper Fang
        [3911] = true, -- Chomp Rush
    },
    DipperYuly = {
        [3904] = true, -- Sudden Lunge
        [3905] = true, -- Spiral Spin
    },
    FlowerpotMerle = {
        [3843] = true, -- Head Butt
        [3845] = true, -- Wild Oats
        [3846] = true, -- Leaf Dagger
    },
    NurseryNazuna = {
        [3857] = true, -- Lamb Chop
        [3859] = true, -- Sheep Charge
    },
    MailbusterCeta = {
        [3938] = true, -- Somersault
    },
    AudaciousAnna = {
        [3851] = true, -- Tail Blow
        [3853] = true, -- Blockhead
        [3854] = true, -- Brain Crush
    },
    BugeyedBroncha = {
        [3891] = true, -- Nimble Snap
        [3892] = true, -- Cyclotail
    },
    GorefangHobs = {
        [3849] = true, -- Razor Fang
        [3850] = true, -- Claw Cyclone
        [3959] = true, -- Crossthrash
    },
    FaithfulFalcor = {
        [3915] = true, -- Back Heel
        [3961] = true, -- Hoof Volley
    },
    CrudeRaphie = {
        [3919] = true, -- Tortoise Stomp
    },
    DapperMac = {
        [3922] = true, -- Wing Slap
        [3923] = true, -- Beak Lunge
    },
    TurbidToloi = {
        [3925] = true, -- Recoil Dive
    },
    SweetCaroline = {
        [3843] = true, -- Head Butt
        [3845] = true, -- Wild Oats
        [3846] = true, -- Leaf Dagger
    },
    AmiableRoche = {
        [3925] = true, -- Recoil Dive
    },
    HeadbreakerKen = {
        [3938] = true, -- Somersault
    },
    AnklebiterJedd = {
        [3894] = true, -- Double Claw
        [3895] = true, -- Grapple
        [3897] = true, -- Spinning Top
    },
    CursedAnnabelle = {
        [3885] = true, -- Mandibular Bite
    },
    BrainyWaluis = {
        [3868] = true, -- Frogkick
    },
    SuspiciousAlice = {
        [3891] = true, -- Nimble Snap
        [3892] = true, -- Cyclotail
    },
    SurgingStorm = {
        [3922] = true, -- Wing Slap
        [3923] = true, -- Beak Lunge
    },
    SubmergedIyo = {
        [3922] = true, -- Wing Slap
        [3923] = true, -- Beak Lunge
    },
    WarlikePatrick = {
        [3851] = true, -- Tail Blow
        [3853] = true, -- Blockhead
        [3854] = true, -- Brain Crush
    },
    RhymingShizuna = {
        [3857] = true, -- Lamb Chop
        [3859] = true, -- Sheep Charge
    },
    BlackbeardRandy = {
        [3849] = true, -- Razor Fang
        [3850] = true, -- Claw Cyclone
        [3959] = true, -- Crossthrash
    },
    ThreestarLynn = {
        [3904] = true, -- Sudden Lunge
        [3905] = true, -- Spiral Spin
    },
    HurlerPercival = {
        [3875] = true, -- Power Attack
        [3877] = true, -- Rhino Attack
    },
    FleetReinhard = {
        [3909] = true, -- Scythe Tail
        [3910] = true, -- Ripper Fang
        [3911] = true, -- Chomp Rush
    },
    SharpwitHermes = {
        [3843] = true, -- Head Butt
        [3845] = true, -- Wild Oats
        [3846] = true, -- Leaf Dagger
    },
    AttentiveIbuki = {
        [3930] = true, -- Swooping Frenzy
        [3933] = true, -- Pentapeck
    },
    SwoopingZhivago = {
        [3930] = true, -- Swooping Frenzy
        [3933] = true, -- Pentapeck
    },
    SunburstMalfik = {
        [3863] = true, -- Big Scissors
    },
    AgedAngus = {
        [3863] = true, -- Big Scissors
    },
    ScissorlegXerin = {
        [3927] = true, -- Sensilla Blades
        [3928] = true, -- Tegmina Buffet
    },
    BouncingBertha = {
        [3927] = true, -- Sensilla Blades
        [3928] = true, -- Tegmina Buffet
    },
    DroopyDortwin = {
        [3840] = true, -- Foot Kick
        [3842] = true, -- Whirl Claws
    },
    PonderingPeter = {
        [3840] = true, -- Foot Kick
        [3842] = true, -- Whirl Claws
    },
    HeraldHenry = {
        [3863] = true, -- Big Scissors
    },
    ['Hip.Familiar'] = {
        [3915] = true, -- Back Heel
        [3961] = true, -- Hoof Volley
    },
    DaringRoland = {
        [3915] = true, -- Back Heel
        [3961] = true, -- Hoof Volley
    },
    ['Y.BeetleFamiliar'] = {
        [3875] = true, -- Power Attack
        [3877] = true, -- Rhino Attack
        [3955] = true, -- Rhinowrecker
    },
    EnergizedSefina = {
        [3875] = true, -- Power Attack
        [3877] = true, -- Rhino Attack
        [3955] = true, -- Rhinowrecker
    },
};

-- Frames are keyed by name. item is the frame's item id.
-- Each weaponskill maps to the automaton skill it needs.
-- Sharpshot uses Automaton Ranged. The others use Automaton Melee.
pets.frames = {
    Harlequin = {
        item = 8224,
        [1943] = 0, -- Slapstick
        [2067] = 145, -- Knockout
        [2301] = 225, -- Magic Mortar
    },
    Valoredge = {
        item = 8225,
        [1940] = 0, -- Chimera Ripper
        [1941] = 0, -- String Clipper
        [2065] = 150, -- Cannibal Blade
        [2299] = 245, -- Bone Crusher
        [2743] = 324, -- String Shredder
    },
    Sharpshot = {
        item = 8226,
        ranged = true,
        [1942] = 0, -- Arcuballista
        [2066] = 150, -- Daze
        [2300] = 245, -- Armor Piercer
        [2744] = 324, -- Armor Shatterer
    },
    Stormwaker = {
        item = 8227,
        [1943] = 0, -- Slapstick
        [2067] = 145, -- Knockout
        [2301] = 225, -- Magic Mortar
    },
};

return pets;
