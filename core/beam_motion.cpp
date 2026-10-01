#include "beam.hpp"
#include "velocity_response.hpp"
#include "ballistic_geometry.hpp"
#include "fixed_math.hpp"
#include <numeric>
namespace astra {
static void share(std::vector<BeamDeposit>& out,const std::vector<BeamTarget>& targets,std::int64_t energy,bool entry,std::array<std::int64_t,16>* previous=nullptr) {
    std::int64_t gcd=0,total=0;
    for(auto& t:targets)gcd=std::gcd(gcd,entry?(t.entering?t.material.entryUj:0):t.material.resistanceUjPerUm);
    if(!energy)return;require(gcd>0,Error::InvalidState);
    for(auto& t:targets)total+=(entry?(t.entering?t.material.entryUj:0):t.material.resistanceUjPerUm)/gcd;
    std::int64_t prefix=0;
    for(auto& t:targets) {
        auto w=(entry?(t.entering?t.material.entryUj:0):t.material.resistanceUjPerUm)/gcd;if(!w)continue;
        // Cyclic integer allocation is monotonic, exactly conserved and independent
        // of the caller's time partition. Normalize weights to minimize quantization.
        auto part=energy/total*w+std::clamp(energy%total-prefix,std::int64_t{0},w);prefix+=w;
        auto delta=part;
        if(previous){auto& old=previous->at(t.contact-1);require(part>=old,Error::InvalidState);delta-=old;old=part;}
        if(delta)out.push_back({t,delta});
    }
}
BeamStep advance_beam(BeamTransit& transit,ballistics::Flight& flight,std::int64_t mass,std::uint32_t duration) {
    using namespace ballistics;require(duration<=1u<<24&&transit.index<transit.slices.size(),Error::InvalidState);BeamStep step;step.remaining=duration;
    while(step.remaining&&transit.index<transit.slices.size()) {
        auto& slice=transit.slices[transit.index];
        if(!transit.motion) {
            auto incoming=velocity_energy(flight.velocity,mass);std::int64_t entry=0,resistance=0;
            for(auto& t:slice.active){if(t.entering)entry+=t.material.entryUj;resistance+=t.material.resistanceUjPerUm;}
            auto after=limit_energy(flight.velocity,mass,std::max(std::int64_t{0},incoming-entry));share(step.deposits,slice.active,incoming-after.energy.outgoingUj,true);
            flight.velocity=after.velocity;flight.position=slice.entry;if(!after.energy.outgoingUj){step.stopped=true;step.remaining=0;return step;}
            auto path=detail::length(slice.entry,slice.exit);require(path>0,Error::InvalidState);
            auto outgoing=std::max(std::int64_t{0},after.energy.outgoingUj-resistance*path);auto exit=limit_energy(after.velocity,mass,outgoing);
            if(!outgoing&&resistance)path=std::clamp(after.energy.outgoingUj/resistance,std::int64_t{1},path);
            BeamMotion m;m.entry=slice.entry;m.pathUm=path;m.entryUj=after.energy.outgoingUj;m.endUj=exit.energy.outgoingUj;
            m.startVelocity=after.velocity;m.endVelocity=exit.velocity;auto full=detail::length(slice.entry,slice.exit);
            for(unsigned i=0;i<3;++i)m.exit[i]=m.entry[i]+fixed::mul_div(slice.exit[i]-m.entry[i],path,full);
            m.duration=std::max(std::int64_t{1},fixed::mul_div(path,std::int64_t{480}*(1u<<24),detail::length({},m.startVelocity)+detail::length({},m.endVelocity)));transit.motion=m;
        }
        auto& m=*transit.motion;auto consumed=std::min<std::int64_t>(step.remaining,m.duration-m.elapsed);m.elapsed+=consumed;step.remaining-=std::uint32_t(consumed);
        for(unsigned i=0;i<3;++i)flight.velocity[i]=m.startVelocity[i]+fixed::mul_div(m.endVelocity[i]-m.startVelocity[i],m.elapsed,m.duration);
        auto current=velocity_energy(flight.velocity,mass);auto absorbed=m.entryUj-current;require(absorbed>=m.absorbedUj&&current>=m.endUj,Error::InvalidState);
        share(step.deposits,slice.active,absorbed,false,&m.distributed);m.absorbedUj=absorbed;
        auto travelled=m.entryUj==m.endUj?fixed::mul_div(m.pathUm,m.elapsed,m.duration):fixed::mul_div(m.pathUm,absorbed,m.entryUj-m.endUj);
        for(unsigned i=0;i<3;++i)flight.position[i]=m.entry[i]+fixed::mul_div(m.exit[i]-m.entry[i],travelled,m.pathUm);
        if(travelled&&!m.vitalEmitted){for(auto& t:slice.active)if(t.vital)step.deposits.push_back({t,0});m.vitalEmitted=true;}
        if(m.elapsed<m.duration)break;
        if(!m.endUj){step.stopped=true;step.remaining=0;return step;}
        transit.motion.reset();++transit.index;
    }
    step.exited=transit.index==transit.slices.size();return step;
}
}
