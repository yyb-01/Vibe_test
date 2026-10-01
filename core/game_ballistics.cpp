#include "beam_scene.hpp"
#include "game_execution.hpp"
#include "ballistic_geometry.hpp"
#include "fixed_math.hpp"
namespace astra {
void run_ballistics(const GameDefinitions& d,World& world,GameState& s,std::uint64_t) {
    using namespace ballistics;std::vector<GameShot> flying;
    for(auto shot:s.shots) {
        auto& p=shot.flight.projectile;auto target=std::min<std::uint64_t>((s.tick*65536-shot.flight.effectiveQ16)/16384,1440);
        while(p.reason==StopReason::Flying&&p.ageSubsteps<target) {
            auto air=ammunition_air(d.ammunition.at(shot.ammoDef),p.flight.velocity);auto divisions=curve_budget(air).divisions;
            unsigned contacts=0;
            for(unsigned division=0;division<divisions&&p.reason==StopReason::Flying;++division) {
                std::uint32_t remaining=(1u<<24)/divisions;
                while(remaining&&p.reason==StopReason::Flying) {
                    if(shot.transit) {
                        auto previous=p.flight.position;auto step=advance_beam(*shot.transit,p.flight,p.massMg,remaining);remaining=step.remaining;
                        p.distanceUpperUm+=detail::length(previous,p.flight.position);apply_beam_damage(s,shot,step.deposits,&world);
                        if(step.stopped)p.reason=StopReason::Barrier;else if(step.exited)shot.transit.reset();
                        continue;
                    }
                    auto elapsed=(1u<<24)/divisions-remaining+(division*(1u<<24)/divisions);
                    auto time=shot.flight.effectiveQ16+std::uint64_t(p.ageSubsteps)*16384+elapsed/1024;
                    auto delay=std::uint64_t(shot.viewDelay)*65536;time=time>=delay?time-delay:0;
                    auto scene=game_layers(d,s,shot,time,p.radiusUm+curve_budget(air).marginUm);Flight proposed;
                    try{proposed=free_flight(p.flight,air,1,remaining);}catch(const Violation& e){if(e.code!=Error::LimitExceeded)throw;p.reason=StopReason::Limit;break;}
                    auto hit=first_layer(p.flight.position,proposed.position,scene);
                    if(!hit){p.distanceUpperUm+=detail::length(p.flight.position,proposed.position);p.flight=proposed;remaining=0;break;}
                    if(++contacts>8||p.contacts>=16){p.reason=StopReason::Limit;break;}
                    auto consumed=std::uint32_t(fixed::mul_div(remaining,hit->second.fraction,1u<<24));auto previous=p.flight.position;
                    p.flight=free_flight(p.flight,air,1,consumed);
                    for(unsigned i=0;i<3;++i)p.flight.position[i]=previous[i]+fixed::mul_div(proposed.position[i]-previous[i],hit->second.entryRatio[0],hit->second.entryRatio[1]);
                    p.distanceUpperUm+=detail::length(previous,p.flight.position);remaining-=consumed;
                    try{shot.transit=start_beam(p.flight,scene,p.contacts);}catch(const Violation& e){if(e.code!=Error::LimitExceeded&&e.code!=Error::InvalidState)throw;p.reason=StopReason::Limit;}
                }
            }
            ++p.ageSubsteps;if(p.ageSubsteps>=1440)p.reason=StopReason::Expired;if(p.distanceUpperUm>=2500000000LL)p.reason=StopReason::Range;
        }
        if(p.reason==StopReason::Flying)flying.push_back(std::move(shot));
    }
    s.shots=std::move(flying);
}
}
