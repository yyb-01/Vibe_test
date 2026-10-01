#include "beam_scene.hpp"
namespace astra {
std::vector<BeamLayer> game_layers(const GameDefinitions& d,const GameState& s,const GameShot& shot,std::uint64_t time,std::int64_t margin) {
    using namespace ballistics;std::vector<BeamLayer> scene;std::uint64_t body=0;
    auto add=[&](Id id,unsigned triangle,Vec3 center,Vec3 extent,BeamTarget target,std::uint64_t bodyId=0) {
        LayerVolume volume;volume.surface={id.hi,id.lo,triangle};volume.layerId=triangle/16+1;volume.bodyId=bodyId;
        double p[]{center.x,center.y,center.z},e[]{extent.x,extent.y,extent.z};
        for(unsigned i=0;i<3;++i){volume.box.min[i]=std::llround((p[i]-e[i])*1e6)-margin;volume.box.max[i]=std::llround((p[i]+e[i])*1e6)+margin;}
        scene.push_back({volume,target});
    };
    for(auto& [id,b]:s.structures) {
        if(b.bornTick*65536>time||(b.destroyed&&b.removedTick*65536<=time))continue;
        auto& def=d.structures.at(b.definition);if(def.kind==StructureKind::Door&&!historical_door(s,id,time))continue;
        BeamTarget target;target.entity=id;target.kind=3;target.material={100000000,20000,1,64000000};add(id,64,b.position,def.halfExtent,target);
    }
    for(auto& actor:historical_actors(s,time)) {
        if(actor.entity==shot.shooter)continue;++body;BeamTarget tissue;tissue.entity=actor.entity;tissue.epoch=actor.epoch;tissue.kind=actor.kind;
        tissue.region=unsigned(Region::Thorax);tissue.material={2000000,4000,1,64000000};
        if(actor.kind==2){tissue.material={50000000,100000,1,64000000};add(actor.entity,48,actor.position,{2,1,.5},tissue);continue;}
        // Axis-aligned reference anatomy; UE supplies animated bone proxies at its boundary.
        constexpr Vec3 centers[]={{0,0,1.7},{0,0,1.3},{0,0,1.0},{0,0,.75},{0,.38,1.24},{0,-.38,1.24},{0,.12,.34},{0,-.12,.34}};
        constexpr Vec3 extents[]={{.13,.13,.16},{.16,.22,.22},{.16,.18,.14},{.17,.2,.16},{.11,.1,.32},{.11,.1,.32},{.13,.1,.34},{.13,.1,.34}};
        for(unsigned region=0;region<8;++region){auto zone=tissue;zone.region=std::uint8_t(region);add(actor.entity,region,actor.position+centers[region],extents[region],zone,body);}
        if(actor.armor) {
            auto armor=tissue;armor.armor=actor.armor->item;armor.kind=4;
            auto& flight=shot.flight.projectile.flight;auto x=actor.position.x-.19;
            auto t=flight.velocity[0]?(x-flight.position[0]/1e6)/(flight.velocity[0]/1e6):0;
            armor.u=std::clamp((flight.position[1]/1e6+flight.velocity[1]/1e6*t-actor.position.y+.2)/.4,0.0,1.0);
            armor.v=std::clamp((flight.position[2]/1e6+flight.velocity[2]/1e6*t-actor.position.z-.82)/.56,0.0,1.0);
            auto integrity=armor_integrity(actor.armor->integrity,armor.u,armor.v);armor.material={std::int64_t(100000000*integrity),std::int64_t(200000*integrity),1,64000000};
            add(actor.entity,16,actor.position+Vec3{-.19,0,1.1},{.02,.2,.28},armor);
        }
        auto vital=tissue;vital.vital=true;vital.material={0,0,1,64000000};add(actor.entity,32,actor.position+Vec3{0,-.06,1.3},{.05,.04,.08},vital);
        vital.region=unsigned(Region::Head);add(actor.entity,33,actor.position+Vec3{0,0,1.7},{.09,.09,.11},vital);
    }
    std::sort(scene.begin(),scene.end(),[](auto& a,auto& b){return a.volume.surface<b.volume.surface;});return scene;
}
std::optional<std::pair<std::size_t,ballistics::BoxHit>> first_layer(ballistics::Vector from,ballistics::Vector to,std::span<const BeamLayer> scene) {
    std::optional<std::pair<std::size_t,ballistics::BoxHit>> best;
    for(std::size_t n=0;n<scene.size();++n) {
        auto& box=scene[n].volume.box;bool leaving=false;
        for(unsigned i=0;i<3;++i)leaving|=(from[i]==box.min[i]&&to[i]<from[i])||(from[i]==box.max[i]&&to[i]>from[i]);
        if(leaving)continue;auto hit=ballistics::sweep_box(from,to,box);
        if(hit&&(!best||hit->fraction<best->second.fraction))best=std::pair{n,*hit};
    }return best;
}
}
