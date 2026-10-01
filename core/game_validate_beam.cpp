#include "game_state.hpp"
namespace astra {
void validate_beam(const GameShot& shot){
    auto contacts=shot.flight.projectile.contacts;
    for(auto [contact,energy]:shot.damageUj)require(contact&&contact<=contacts&&energy>=0&&energy<=2000000000000LL,Error::InvalidState);
    if(!shot.transit)return;auto& t=*shot.transit;
    require(!t.slices.empty()&&t.slices.size()<=32&&t.index<t.slices.size(),Error::InvalidState);
    for(auto& slice:t.slices){
        require(slice.entry!=slice.exit&&!slice.active.empty()&&slice.active.size()<=16,Error::InvalidState);
        for(auto& target:slice.active){
            require(target.entity&&target.kind<=4&&target.region<8&&target.contact&&target.contact<=contacts&&
                (target.kind!=0||target.epoch)&&(target.kind!=4||target.armor),Error::InvalidState);
            auto& m=target.material;require(m.entryUj>=0&&m.entryUj<=2000000000000LL&&m.resistanceUjPerUm>=0&&m.resistanceUjPerUm<=100000000&&
                m.minPathUm>=1&&m.minPathUm<=m.maxPathUm&&m.maxPathUm<=64000000,Error::InvalidState);
            bounded(target.u,0,1);bounded(target.v,0,1);
        }
    }
    if(t.motion){
        auto& m=*t.motion;
        require(m.pathUm>0&&m.pathUm<=64000000&&m.duration>0&&m.elapsed>=0&&m.elapsed<m.duration&&
            m.entryUj>=m.endUj&&m.endUj>=0&&m.entryUj<=2000000000000LL&&m.absorbedUj>=0&&m.absorbedUj<=m.entryUj-m.endUj,Error::InvalidState);
        std::int64_t total=0;for(auto energy:m.distributed){require(energy>=0&&energy<=m.absorbedUj,Error::InvalidState);total+=energy;}
        require(total==m.absorbedUj,Error::InvalidState);
        ballistics::free_flight({m.entry,m.startVelocity},{},1,0);ballistics::free_flight({m.exit,m.endVelocity},{},1,0);
    }
}
}
