#pragma once
#include "state_survival.hpp"
#include "world_simulation.hpp"
namespace astra {
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,Support>
void state_fields(A& a,V& v){a(v.parent,v.share,v.capacityG);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,Structure>
void state_fields(A& a,V& v){a(v.entity,v.owner,v.revision,v.lastDamageEvent,v.lastTriggerTick,v.definition,v.position,v.health,v.bornTick,v.removedTick,v.destroyed,v.open,v.locked,v.armed);a.sequence(v.supports,8);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,Cell>
void state_fields(A& a,V& v){a(v.pins,v.dirtyRevision,v.savedRevision,v.loaded,v.wanted);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,Zombie>
void state_fields(A& a,V& v){a(v.entity,v.target,v.position,v.investigate,v.revision,v.lastAttackTick,v.lastStimulus,v.health,v.hearingDb,v.speedMS,v.mode);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,WorldSimulation>
void state_fields(A& a,V& v){a(v.cells,v.pathBudget);a.dictionary(v.zombies,800);if(a.version>=2)a.sequence(v.stimuli,1024);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,Stimulus>
void state_fields(A& a,V& v){a(v.event,v.tick,v.source,v.position,v.kind,v.radiusM,v.soundDb,v.heatWatts,v.durationTicks);}
}
