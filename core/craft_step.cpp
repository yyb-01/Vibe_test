#include "crafting.hpp"
#include "mutation.hpp"
#include "fixed_math.hpp"
#include "game_flags.hpp"
namespace astra {
void advance_craft(const Catalog& cat,World& w,Crafting& c,CraftJob& j,const Recipe& r,std::uint64_t dt,std::uint64_t available,Id first,std::uint64_t event) {
    require(j.recipe==r.id&&j.version==r.version&&dt<=1000000,Error::Incompatible);
    if(j.phase!=JobPhase::Running&&j.phase!=JobPhase::Paused)return;
    require(!c.stations.at(j.station).destroyed&&j.progressUs<=r.durationUs,Error::InvalidState);
    auto energy=r.energyUj*j.batch;
    auto cost=[&](std::uint64_t progress){return r.durationUs?std::uint64_t(fixed::mul_div(std::int64_t(energy),std::int64_t(progress),std::int64_t(r.durationUs))):energy;};
    auto proposed=std::min(r.durationUs,j.progressUs+dt);
    if(cost(proposed)-j.energyUj>available) {
        if(!r.partialPower){j.phase=JobPhase::Paused;return;}
        auto lo=j.progressUs,hi=proposed;
        while(lo<hi){auto mid=lo+(hi-lo+1)/2;if(cost(mid)-j.energyUj<=available)lo=mid;else hi=mid-1;}proposed=lo;
        if(proposed==j.progressUs){j.phase=JobPhase::Paused;return;}
    }
    auto old=j.progressUs;
    for(std::size_t n=0;n<j.tools.size();++n) {
        auto total=std::uint64_t(r.tools[n].wear)*j.batch;
        auto loss=r.durationUs?total*proposed/r.durationUs-total*old/r.durationUs:total;
        if(loss>w.items.at(j.tools[n]).durability){j.phase=JobPhase::Paused;return;}
    }
    j.progressUs=proposed;j.energyUj=cost(proposed);j.phase=JobPhase::Running;
    for(std::size_t n=0;n<j.tools.size();++n) {
        auto& tool=w.items.at(j.tools[n]);auto total=std::uint64_t(r.tools[n].wear)*j.batch;
        auto loss=r.durationUs?total*proposed/r.durationUs-total*old/r.durationUs:total;
        require(loss<=tool.durability,Error::Incompatible);if(loss){tool.durability-=loss;bump(tool.revision);}
    }
    auto next=first.lo;
    while(j.stage<r.stages.size()&&(!r.durationUs||j.progressUs*1000>=r.durationUs*r.stages[j.stage])) {
        for(auto input:r.inputs)if(input.stage==j.stage) {
            std::uint64_t need=std::uint64_t(input.quantity)*j.batch;
            for(auto id:j.inputs) {
                auto& item=w.items.at(id);if(item.defId!=input.def||!item.quantity)continue;
                if(item.defId==r.repairDef){require(item.quantity==1,Error::InvalidState);item.durability=65535;bump(item.revision);j.outputs.push_back(id);need-=1;continue;}
                auto quantity=std::uint32_t(std::min<std::uint64_t>(need,item.quantity));if(quantity)consume_item(w,id,quantity);need-=quantity;
            }
            require(!need,Error::InvalidState);
        }
        for(std::size_t index=0;index<r.outputs.size();++index) {
            auto row=r.outputs[index];auto stage=row.stage==255?r.stages.size()-1:row.stage;
            if(stage!=j.stage)continue;
            auto random=j.seed^(index*0x9e3779b97f4a7c15ULL);random^=random>>30;random*=0xbf58476d1ce4e5b9ULL;
            if(!row.probability||(row.probability!=65535&&(random&65535)>=row.probability))continue;
            auto remaining=std::uint64_t(row.quantity)*j.batch;
            while(remaining) {
                ItemState item;item.id={first.hi,next++};item.defId=row.def;item.quantity=std::uint32_t(std::min<std::uint64_t>(cat.at(row.def).maxStack,remaining));item.birthEvent=event;
                require(w.items.emplace(item.id,item).second,Error::InvalidState);place_item(cat,w,item.id,j.escrow);j.outputs.push_back(item.id);remaining-=item.quantity;
            }
        }
        ++j.stage;
        std::erase_if(j.inputs,[&](Id id){return !w.placements.contains(id);});
    }
    if(j.stage==r.stages.size()) {j.phase=JobPhase::OutputReady;for(auto id:j.tools){c.toolLeases.erase(id);w.items.at(id).flags&=~leased_tool;bump(w.items.at(id).revision);}}
    ++j.revision;
}
void cancel_craft(const Catalog&,World& w,Crafting& c,CraftJob& j,bool destroyed) {
    require(j.phase==JobPhase::Running||j.phase==JobPhase::Paused||j.phase==JobPhase::OutputReady,Error::InvalidRequest);
    for(auto id:j.tools)if(c.toolLeases.contains(id)&&c.toolLeases.at(id)==j.entity) {
        c.toolLeases.erase(id);w.items.at(id).flags&=~leased_tool;bump(w.items.at(id).revision);
    }
    j.phase=destroyed?JobPhase::Destroyed:JobPhase::Cancelled;++j.revision;
}
void collect_craft(const Catalog& cat,World& w,CraftJob& j,Id target) {
    require(j.phase==JobPhase::OutputReady||j.phase==JobPhase::Cancelled||j.phase==JobPhase::Destroyed,Error::InvalidRequest);
    std::vector<Id> items;for(const auto& [id,p]:w.placements)if(p.container==j.escrow)items.push_back(id);
    for(auto id:items){place_item(cat,w,id,target);bump(w.items.at(id).revision);}
    j.inputs.clear();j.outputs.clear();j.tools.clear();j.phase=JobPhase::Collected;++j.revision;
}
}
