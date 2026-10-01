#include "game_state.hpp"
namespace astra {
void economy_definitions(GameDefinitions& d) {
    Recipe bandage;bandage.id=1;bandage.capabilities=1;bandage.durationUs=1000000;
    bandage.inputs={{110,2,0,0}};bandage.outputs={{111,1}};d.recipes.emplace(1,bandage);
    Recipe ammo;ammo.id=2;ammo.tier=2;ammo.capabilities=2;ammo.unlock=1;ammo.prerequisites={1};
    ammo.durationUs=2000000;ammo.energyUj=1000000000;ammo.stages={500,1000};ammo.inputs={{109,2,0,0}};ammo.outputs={{105,5}};ammo.tools={{114,10}};d.recipes.emplace(2,ammo);
    auto battery=ammo;battery.id=3;battery.tier=3;battery.capabilities=4;battery.unlock=2;battery.prerequisites={2};
    battery.inputs={{109,10,0,0},{108,2,0,1}};battery.outputs={{122,1}};battery.partialPower=true;d.recipes.emplace(3,battery);
    auto engine=battery;engine.id=4;engine.tier=4;engine.capabilities=8;engine.unlock=3;engine.prerequisites={3};
    engine.inputs={{109,20,0,0},{116,10,0,1}};engine.outputs={{121,1}};d.recipes.emplace(4,engine);
    Recipe repair;repair.id=5;repair.capabilities=1;repair.durationUs=1000000;repair.repairDef=100;
    repair.inputs={{100,1,0,0},{109,2,0,0},{116,2,0,0}};repair.tools={{114,5}};d.recipes.emplace(5,repair);
    Recipe dismantle;dismantle.id=6;dismantle.capabilities=1;dismantle.durationUs=1000000;
    dismantle.inputs={{122,1,0,0}};dismantle.outputs={{109,5},{116,4}};dismantle.tools={{114,10}};d.recipes.emplace(6,dismantle);
    dismantle.id=7;dismantle.inputs={{121,1,0,0}};dismantle.outputs={{109,20},{116,10}};d.recipes.emplace(7,dismantle);
    for(unsigned i=0;i<8;++i) {
        StructureDef b;b.id=10+i;b.kind=StructureKind(i);b.materials={{108,2},{109,1}};
        b.halfExtent=i==0?Vec3{1,1,.1}:i==1||i==4?Vec3{.1,1,1}:Vec3{1,1,.1};
        b.massG=1000;b.capacityG=1000000;d.structures.emplace(b.id,b);
    }
    for(unsigned id=17;id<=19;++id){
        StructureDef b;b.id=id;b.kind=StructureKind::Utility;b.halfExtent={.5,.5,.35};b.massG=20000;
        b.capacityG=1000000;b.maxCargoG=100000;b.materials={{108,5},{109,5}};d.structures.insert_or_assign(id,b);
    }
}
}
