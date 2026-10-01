#include "game_state.hpp"
#include <set>
namespace astra {
void validate_economy(const GameState&);
void validate_world_state(const GameState&);
void validate_controls(const GameState&);
void validate_beam(const GameShot&);
void validate_game(const GameState& s) {
    require(s.catalogVersion&&s.revision&&s.revision<=revision_limit&&s.nextShot&&s.tick<=revision_limit/65536,
        Error::InvalidState);
    require(s.lives.size()<=20&&s.weapons.size()<=512&&s.armor.size()<=512&&s.vehicles.size()<=20&&
        s.structures.size()<=10000&&s.shots.size()<=2048&&s.unlocks.size()<=64,Error::LimitExceeded);
    std::set<Id> accounts;
    for(auto& [id,l]:s.lives){validate_life(l);require(id==l.entity&&l.tick<=s.tick&&accounts.insert(l.account).second,Error::InvalidState);}
    for(auto& [id,w]:s.weapons) {
        require(id&&id==w.item&&w.netId&&w.generation&&w.revision&&w.assemblyRevision&&unsigned(w.phase)<=5,Error::InvalidState);
        bounded(w.heatK,200,2000);bounded(w.fouling,0,1);bounded(w.recoilPitch,-10,10);bounded(w.recoilYaw,-10,10);
    }
    for(auto& [id,v]:s.vehicles) {
        require(id&&id==v.entity&&v.revision&&v.assemblyRevision&&v.physicsRevision&&v.tick<=s.tick&&
            finite(v.position)&&finite(v.velocity)&&finite(v.omega)&&v.wheels.size()<=6,Error::InvalidState);
        combine_mass(v.parts);bounded(v.engineRpm,0,30000);bounded(v.clutch,0,1);bounded(v.steer,-1,1);
        bounded(v.fuelResidual,0,1e9);bounded(v.batteryResidual,0,1e9);
        for(auto& w:v.wheels){bounded(w.omega,-10000,10000);bounded(w.compression,0,5);bounded(w.temperatureK,200,2000);bounded(w.wear,0,1);}
    }
    validate_economy(s);validate_world_state(s);validate_controls(s);
    std::uint64_t previous=0;
    for(auto& shot:s.shots) {
        auto& p=shot.flight.projectile;
        require(p.shotId>previous&&p.shotId<s.nextShot&&shot.shooter&&shot.ammoDef&&shot.viewDelay<=30&&
            shot.flight.effectiveQ16<=s.tick*65536&&p.ageSubsteps<=1440&&p.contacts<=16&&unsigned(p.reason)<=4&&
            p.massMg>0&&p.massMg<=1000000&&p.radiusUm>=0&&p.radiusUm<=100000,Error::InvalidState);
        ballistics::free_flight(p.flight,{},1,0);previous=p.shotId;
        validate_beam(shot);
    }
    for(auto& [id,rows]:s.unlocks) {
        require(id&&rows.size()<=10000,Error::InvalidState);std::uint32_t last=0;
        for(auto row:rows){require(row>last,Error::InvalidState);last=row;}
    }
}
}
