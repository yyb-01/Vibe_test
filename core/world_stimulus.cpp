#include "world_simulation.hpp"
namespace astra {
void StimulusQueue::publish(const Stimulus& s) {
    require(s.event&&finite(s.position)&&unsigned(s.kind)<=4&&s.durationTicks<=3600,Error::InvalidRequest);
    bounded(s.radiusM,0,2500);bounded(s.soundDb,0,200);bounded(s.heatWatts,0,1e9);
    if(s.kind==StimulusKind::Engine||s.kind==StimulusKind::Machine) {
        for(auto& old:queue_)if(old.source==s.source&&old.kind==s.kind&&old.tick/6==s.tick/6&&cell_of(old.position)==cell_of(s.position)) {
            old.soundDb=10*std::log10(std::pow(10,old.soundDb/10)+std::pow(10,s.soundDb/10));
            old.heatWatts+=s.heatWatts;old.radiusM=std::max(old.radiusM,s.radiusM);return;
        }
    }
    if(queue_.size()==1024)queue_.pop_front();queue_.push_back(s);
}
std::vector<Stimulus> StimulusQueue::take(std::uint64_t tick) {
    std::vector<Stimulus> result;
    for(auto i=queue_.begin();i!=queue_.end();) {
        require(i->tick<=tick,Error::InvalidRequest);
        if(tick-i->tick>i->durationTicks)i=queue_.erase(i);
        else {result.push_back(*i);i=queue_.erase(i);}
    }return result;
}
}
