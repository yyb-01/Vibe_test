#include "crafting.hpp"
#include <functional>
namespace astra {
void validate_recipes(const Catalog& cat,const std::map<std::uint32_t,Recipe>& recipes) {
    require(recipes.size()<=10000,Error::LimitExceeded);std::map<std::uint32_t,unsigned> marks;
    std::function<void(std::uint32_t)> visit=[&](auto id) {
        require(recipes.contains(id)&&marks[id]!=1,Error::CycleDetected);if(marks[id]==2)return;marks[id]=1;
        for(auto parent:recipes.at(id).prerequisites)visit(parent);marks[id]=2;
    };
    for(const auto& [id,r]:recipes) {
        require(id&&r.id==id&&r.version&&r.tier>=1&&r.tier<=4&&r.inputs.size()<=32&&r.outputs.size()<=32&&r.tools.size()<=8&&r.stages.size()<=32&&!r.stages.empty()&&r.stages.back()==1000,Error::InvalidState);
        require(r.durationUs<=86400000000ULL&&r.energyUj<=1000000000000000ULL,Error::InvalidState);
        unsigned previous=0;for(auto step:r.stages){require(step>previous&&step<=1000,Error::InvalidState);previous=step;}
        std::set<std::uint32_t> inputDefs;
        for(auto row:r.inputs)require(cat.contains(row.def)&&row.quantity&&row.quantity<=1000000&&row.stage<r.stages.size()&&inputDefs.insert(row.def).second,Error::InvalidState);
        for(auto row:r.outputs)require(cat.contains(row.def)&&row.quantity&&row.quantity<=cat.at(row.def).maxStack&&(row.stage==255||row.stage<r.stages.size()),Error::InvalidState);
        for(auto row:r.tools)require(cat.contains(row.def)&&cat.at(row.def).maxStack==1,Error::InvalidState);
        if(r.repairDef)require(cat.contains(r.repairDef)&&cat.at(r.repairDef).maxStack==1&&inputDefs.contains(r.repairDef)&&r.outputs.empty()&&
            std::count_if(r.inputs.begin(),r.inputs.end(),[&](auto i){return i.def==r.repairDef&&i.quantity==1&&std::size_t(i.stage)+1==r.stages.size();})==1,Error::InvalidState);
        visit(id);
    }
}
}
