#include "world_simulation.hpp"
namespace astra {
void publish_stimulus(WorldSimulation& world,const Stimulus& stimulus){
    StimulusQueue queue;for(auto& s:world.stimuli)queue.publish(s);queue.publish(stimulus);world.stimuli=queue.take(stimulus.tick);
}
}
