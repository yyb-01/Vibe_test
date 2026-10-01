#include "game_command.hpp"
#include "chamber.hpp"
#include "magazine.hpp"
namespace astra {
void seed_player(const GameDefinitions&,World&,GameState&,unsigned);
void seed_vehicle(const GameDefinitions&,World&,GameState&);
static Id sid(std::uint64_t n){return {5,n};}
Checkpoint survival_seed(const GameDefinitions& d,unsigned players) {
    require(players&&players<=20,Error::InvalidRequest);validate_definitions(d);World w;GameState game;game.catalogVersion=d.version;
    for(auto id:{game_root,ground_root,station_root}){Container c;c.state.id=id;c.kind=PlaceKind::World;c.state.capacityMl=UINT32_MAX;w.containers.emplace(id,c);}
    for(unsigned i=0;i<players;++i)seed_player(d,w,game,i);
    for(unsigned i=0;i<4;++i) {
        Station station;station.entity=sid(4000+i);station.item=sid(4100+i);station.output=sid(4200+i);
        station.capabilities=1u<<i;station.position={double(i),2,0};station.powerNode=sid(4300+i);
        ItemState bench;bench.id=station.item;bench.defId=115;w.items.emplace(bench.id,bench);place_item(d.items,w,bench.id,station_root);
        Container output;output.state.id=station.output;output.state.ownerItem=station.item;output.state.width=output.state.height=16;output.state.capacityMl=UINT32_MAX;
        w.containers.emplace(station.output,output);game.crafting.stations.emplace(station.entity,station);
        PowerNode load;load.entity=station.powerNode;load.position=station.position;load.priority=i;game.power.nodes.emplace(load.entity,load);
    }
    PowerNode generator;generator.entity=sid(4400);generator.position={0,2,0};generator.generateW=5000;generator.fuelUj=1000000000000ULL;
    game.power.nodes.emplace(generator.entity,generator);
    for(unsigned i=0;i<4;++i)game.power.cables.push_back({generator.entity,sid(4300+i),10});
    seed_vehicle(d,w,game);
    const std::array<unsigned,8> loot{112,113,111,124,105,106,119,122};
    for(unsigned i=0;i<loot.size();++i){
        ItemState item;item.id=sid(7100+i);item.defId=loot[i];item.quantity=i==4||i==5?20:1;w.items.emplace(item.id,item);place_item(d.items,w,item.id,ground_root);
        GroundAsset asset;asset.item=item.id;asset.position={20+double(i)*5,8,0};asset.spawnDef=item.defId;asset.quantity=item.quantity;asset.cycle=1;asset.nextSpawnTick=18000;
        game.groundAssets.emplace(sid(7000+i),asset);
    }
    for(unsigned i=0;i<8;++i){Zombie z;z.entity=sid(5000+i);z.position={20+double(i)*2,0,0};game.world.zombies.emplace(z.entity,z);}
    record_history(w,game);w.containers.at(game_root).gameplay=encode_game(game);validate(d.items,w);
    Checkpoint result;result.catalog=d.items;result.world=std::move(w);result.epoch=1;result.origin=6;return result;
}
}
