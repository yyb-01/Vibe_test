#include "check.hpp"
#include "game_command.hpp"
#include "beam.hpp"
using namespace astra;
void game_systems() {
    Life a;a.entity={1,1};a.account={2,1};a.inventory={3,1};wound(a,1,Region::LeftArm,100,false);auto b=a;
    Environment env;advance_life(a,env,600);for(unsigned t=60;t<=600;t+=60)advance_life(b,env,t);
    CHECK(a.bloodMl==b.bloodMl&&a.hydrationMl==b.hydrationMl&&a.coreK==b.coreK&&a.skinK==b.skinK);
    auto blood=a.bloodMl;advance_life(a,env,600);CHECK(a.bloodMl==blood);
    auto hp=a.health[2];wound_progress(a,2,Region::Abdomen,50,false);wound_progress(a,2,Region::Abdomen,50,false);CHECK(a.health[2]==hp-5);
    rejects([&]{advance_life(a,env,599);},Error::InvalidRequest);
    std::vector<MassPart> parts{{{1,1},10,{-1,0,0},diagonal(1,2,2)},{{1,2},20,{1,0,0},diagonal(2,3,3)}};
    auto mass=combine_mass(parts);CHECK(std::abs(mass.com.x-1.0/3)<1e-12);
    auto motion=detach_part(parts,{1,1},{4,2,1},{0,0,2});
    auto total=motion.chassisVelocity*20+motion.partVelocity*10;CHECK(length(total-Vec3{120,60,30})<1e-9);
    auto spin=transform(motion.remaining.inertia,motion.chassisOmega)+cross(motion.remaining.com,motion.chassisVelocity*20)+transform(parts[0].inertia,motion.partOmega)+cross(parts[0].com,motion.partVelocity*10);
    auto before=transform(mass.inertia,{0,0,2})+cross(mass.com,Vec3{120,60,30});CHECK(length(spin-before)<1e-9);
    Wheel wheel;WheelDef def;def.radius=.3;WheelContact contact;contact.hit=true;contact.distance=.55;contact.normal={std::sqrt(.75),0,.5};
    auto force=wheel_force(wheel,def,contact,0,0,1.0/60);CHECK(wheel.compression==.3&&force.load>=0);
    PowerGrid grid;PowerNode generator;generator.entity={1,1};generator.generateW=1000;generator.fuelUj=1000000000;
    PowerNode load;load.entity={1,2};load.demandW=500;load.priority=0;
    PowerNode battery;battery.entity={1,3};battery.capacityUj=1000000000;battery.chargeW=1000;battery.chargeEfficiency=32768;
    grid.nodes={{generator.entity,generator},{load.entity,load},{battery.entity,battery}};grid.cables={{generator.entity,load.entity},{load.entity,battery.entity},{battery.entity,generator.entity}};
    auto energy=allocate_power(grid,1000000);CHECK(energy.loadUj==500000000&&energy.generatedUj+energy.initialBatteryUj==energy.finalBatteryUj+energy.loadUj+energy.lossUj+energy.unusedUj);
    auto defs=survival_definitions();auto seed=survival_seed(defs,20);auto game=decode_game(seed.world.containers.at(game_root).gameplay);CHECK(game.lives.size()==20&&game.vehicles.size()==1&&game.history.size()==1);
    auto encoded=encode_game(game);CHECK(encode_game(decode_game(encoded))==encoded);encoded.push_back(0);rejects([&]{decode_game(encoded);},Error::InvalidState);
    std::array<Observer,2> observers{{{{-500,0,0},false},{{500,0,0},true}}};auto cells=active_cells(observers);CHECK(cells[cell_of(observers[0].position)]&&cells[cell_of(observers[1].position)]);
    Cell cell;cell.loaded=true;pin(cell,PinReason::Projectile,1);CHECK(!can_unload(cell));pin(cell,PinReason::Projectile,-1);CHECK(can_unload(cell));
}
