#include "game_command.hpp"
namespace astra {
void weapon_definitions(GameDefinitions&);
void economy_definitions(GameDefinitions&);
GameDefinitions survival_definitions() {
    GameDefinitions d;d.version=2;
    auto add=[&](std::uint32_t id,std::uint32_t mass,std::uint32_t stack=1,std::uint32_t part=0,bool container=false) {
        ItemDef item;item.id=id;item.massG=mass;item.outerVolumeMl=mass;item.maxStack=stack;
        item.partDefId=part;item.containerDefId=container?1:0;d.items.emplace(id,item);
    };
    add(100,1800,1,1,true);add(101,700,1,2,true);add(102,200,1,3);add(103,300,1,4);add(104,250,1,5,true);
    add(105,8,100);add(106,10,100);add(107,500,1,0,true);
    add(108,100,1000);add(109,50,1000);add(110,10,1000);add(111,10,20);d.items.at(111).flags=256;
    add(112,500,10);add(113,250,10);add(114,500);add(115,20000,1,0,true);add(116,30,1000);
    add(117,3000,1,6);add(118,900000,1,7,true);add(119,20000,1,8);
    add(120,1000,1,0,true);add(121,150000,1,9);add(122,10000,1,10);add(123,15000,1,11);
    add(124,750,10);d.items.at(124).outerVolumeMl=1000;
    weapon_definitions(d);economy_definitions(d);
    d.foods.emplace(112,FoodProfile{500,0,{}});d.foods.emplace(113,FoodProfile{100,500,{}});
    d.wheels.resize(4);unsigned i=0;
    for(double x:{1.2,-1.2})for(double y:{.8,-.8})d.wheels[i++].anchor={x,y,0};
    validate_definitions(d);return d;
}
}
