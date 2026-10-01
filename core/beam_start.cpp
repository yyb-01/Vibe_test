#include "beam.hpp"
#include "ballistic_geometry.hpp"
#include "fixed_math.hpp"
namespace astra {
BeamTransit start_beam(const ballistics::Flight& f,std::span<const BeamLayer> scene,std::uint16_t& contacts) {
    using namespace ballistics;auto speed=detail::length({},f.velocity);require(speed>0,Error::InvalidRequest);
    Vector from=f.position,to=f.position;for(unsigned i=0;i<3;++i){from[i]-=fixed::mul_div(f.velocity[i],1,speed);to[i]+=fixed::mul_div(f.velocity[i],64000000,speed);}
    std::vector<LayerVolume> volumes;for(auto& layer:scene)volumes.push_back(layer.volume);
    auto paths=layer_paths(from,to,volumes);require(!paths.empty(),Error::InvalidState);
    struct Row {std::int64_t begin,end;BeamTarget target;Vector entry,exit;};std::vector<Row> rows;std::vector<std::int64_t> boundaries;
    std::int64_t end=2;
    for(auto& path:paths) {
        auto begin=detail::length(from,path.entry);if(begin>end)break;
        require(path.complete&&contacts<16,Error::LimitExceeded);auto stop=detail::length(from,path.exit);end=std::max(end,stop);
        auto source=std::find_if(scene.begin(),scene.end(),[&](auto& l){return l.volume.surface==path.surface;});require(source!=scene.end(),Error::InvalidState);
        auto target=source->target;target.contact=++contacts;rows.push_back({begin,stop,target,path.entry,path.exit});boundaries.push_back(begin);boundaries.push_back(stop);
    }
    require(!rows.empty(),Error::InvalidState);std::sort(boundaries.begin(),boundaries.end());boundaries.erase(std::unique(boundaries.begin(),boundaries.end()),boundaries.end());
    BeamTransit transit;
    auto point=[&](std::int64_t distance){Vector p{};for(unsigned i=0;i<3;++i)p[i]=from[i]+fixed::mul_div(to[i]-from[i],distance,detail::length(from,to));return p;};
    for(std::size_t i=1;i<boundaries.size();++i) {
        BeamSlice slice{point(boundaries[i-1]),point(boundaries[i]),{}};
        for(auto& row:rows)if(row.begin<=boundaries[i-1]&&row.end>=boundaries[i]){auto target=row.target;target.entering=row.begin==boundaries[i-1];slice.active.push_back(target);}
        require(!slice.active.empty(),Error::InvalidState);transit.slices.push_back(std::move(slice));
    }
    require(!transit.slices.empty()&&transit.slices.size()<=32,Error::LimitExceeded);return transit;
}
}
