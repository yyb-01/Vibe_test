#include "game_state.hpp"
#include "state_vehicle.hpp"
#include "state_economy.hpp"
#include "state_world.hpp"
#include "state_control.hpp"
#include "state_history.hpp"
#include "state_beam.hpp"
namespace astra {
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,ballistics::Flight>
void state_fields(A& a,V& v){a(v.position,v.velocity);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,ballistics::Projectile>
void state_fields(A& a,V& v){a(v.flight,v.shotId,v.massMg,v.radiusUm,v.ageSubsteps,v.reason,v.distanceUpperUm,v.contacts);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,ShotFlight>
void state_fields(A& a,V& v){a(v.projectile,v.effectiveQ16);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,GameShot>
void state_fields(A& a,V& v){a(v.flight,v.shooter,v.ammoDef,v.viewDelay);a.optional(v.transit);a.dictionary(v.damageUj,16);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,GameState>
void state_fields(A& a,V& v){
    a(v.catalogVersion,v.revision,v.tick,v.nextShot,v.crafting,v.power,v.world);
    a.dictionary(v.lives,20);a.dictionary(v.weapons,512);a.dictionary(v.armor,512);a.dictionary(v.vehicles,20);
    a.dictionary(v.controls,20);
    a.dictionary(v.drivingInputs,20);a.dictionary(v.groundAssets,10000);
    a.sequence(v.history,31);
    a.dictionary(v.structures,10000);a.sequence(v.shots,2048);a.dictionary(v.lootCycles,10000);
    if constexpr(std::is_same_v<A,StateSave>) {
        a.writer.put(v.unlocks.size(),4);for(auto& [id,rows]:v.unlocks){a(id);a.sequence(rows,10000);}
    } else {
        auto n=a.count(64);for(std::size_t i=0;i<n;++i){Id id;std::vector<std::uint32_t> rows;a(id);a.sequence(rows,10000);require(v.unlocks.emplace(id,std::move(rows)).second,Error::InvalidState);}
    }
}
std::vector<std::uint8_t> encode_game(const GameState& state) {
    validate_game(state);StateSave s;s.writer.put(0x414d4147,4);s.writer.put(s.version,4);s.value(state);
    require(s.writer.bytes.size()<=16*1024*1024,Error::LimitExceeded);return std::move(s.writer.bytes);
}
GameState decode_game(const std::vector<std::uint8_t>& bytes) {
    require(bytes.size()>=16&&bytes.size()<=16*1024*1024,Error::InvalidState);StateLoad s{{bytes}};
    require(s.reader.get(4)==0x414d4147,Error::Incompatible);s.version=unsigned(s.reader.get(4));require(s.version>=1&&s.version<=2,Error::Incompatible);GameState state;s.value(state);
    require(s.reader.position==bytes.size(),Error::InvalidState);validate_game(state);return state;
}
}
