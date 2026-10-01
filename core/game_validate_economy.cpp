#include "game_state.hpp"
#include <set>
namespace astra {
void validate_economy(const GameState& s) {
    auto& c=s.crafting;
    require(c.jobs.size()<=1024&&c.stations.size()<=256&&c.toolLeases.size()<=8192,Error::LimitExceeded);
    for(auto& [id,station]:c.stations)require(id&&id==station.entity&&station.item&&station.output&&station.revision&&finite(station.position),Error::InvalidState);
    for(auto& [id,j]:c.jobs) {
        require(id&&id==j.entity&&j.owner&&j.request&&j.escrow&&j.source&&j.revision&&j.recipe&&j.version&&j.batch&&j.batch<=100&&
            unsigned(j.phase)<=5&&j.stage<=32&&j.inputs.size()<=32&&j.tools.size()<=8&&j.outputs.size()<=3200&&c.stations.contains(j.station),Error::InvalidState);
        if(j.phase==JobPhase::Running||j.phase==JobPhase::Paused)for(auto tool:j.tools)
            require(c.toolLeases.contains(tool)&&c.toolLeases.at(tool)==id,Error::InvalidState);
    }
    for(auto [tool,job]:c.toolLeases)require(tool&&c.jobs.contains(job)&&
        (c.jobs.at(job).phase==JobPhase::Running||c.jobs.at(job).phase==JobPhase::Paused),Error::InvalidState);
    auto grid=s.power;allocate_power(grid,1); // Also checks graph caps, duplicate edges and component limits.
}
void validate_world_state(const GameState& s) {
    require(s.world.stimuli.size()<=1024,Error::LimitExceeded);
    for(auto& event:s.world.stimuli){require(event.event&&event.source&&event.tick<=s.tick&&finite(event.position)&&unsigned(event.kind)<=4&&event.durationTicks&&event.durationTicks<=36000,Error::InvalidState);bounded(event.radiusM,0,4000);bounded(event.soundDb,0,200);bounded(event.heatWatts,0,1e9);}
    require(s.world.zombies.size()<=800&&s.world.pathBudget<=64,Error::LimitExceeded);
    for(auto& [id,z]:s.world.zombies) {
        require(id&&id==z.entity&&z.revision&&finite(z.position)&&finite(z.investigate)&&unsigned(z.mode)<=4&&z.lastAttackTick<=s.tick,Error::InvalidState);
        bounded(z.health,0,100000);bounded(z.hearingDb,0,200);bounded(z.speedMS,0,20);cell_of(z.position);
    }
    for(auto& [id,b]:s.structures) {
        require(id&&id==b.entity&&b.owner&&b.revision&&b.definition&&b.supports.size()<=8&&b.position==normalize_build(b.position),Error::InvalidState);
        std::uint32_t total=0;std::set<Id> seen;
        for(auto edge:b.supports) {
            require(s.structures.contains(edge.parent)&&seen.insert(edge.parent).second&&edge.share&&edge.capacityG,
                Error::InvalidState);auto& parent=s.structures.at(edge.parent);
            require(parent.position.z<b.position.z||(parent.position.z==b.position.z&&parent.entity<id),Error::CycleDetected);total+=edge.share;
        }
        require(b.supports.empty()||total==65535,Error::InvalidState);
    }
    for(auto& cell:s.world.cells)require(cell.savedRevision<=cell.dirtyRevision,Error::InvalidState);
}
}
