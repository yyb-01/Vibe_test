#include "game_command.hpp"
namespace astra {
unsigned craft_output_budget(const GameDefinitions& d,const CraftJob& j,std::uint64_t dt) {
    auto& r=d.recipes.at(j.recipe);auto progress=std::min(r.durationUs,j.progressUs+dt);unsigned count=0;
    for(auto o:r.outputs) {
        auto stage=o.stage==255?r.stages.size()-1:o.stage;
        if(stage<j.stage||(r.durationUs&&progress*1000<r.durationUs*r.stages.at(stage)))continue;
        auto n=std::uint64_t(o.quantity)*j.batch;count+=unsigned((n+d.items.at(o.def).maxStack-1)/d.items.at(o.def).maxStack);
    }
    return count;
}
}
