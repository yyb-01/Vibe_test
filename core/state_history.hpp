#pragma once
#include "state_survival.hpp"
#include "game_history.hpp"
namespace astra {
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,HistoryArmor>
void state_fields(A& a,V& c){a(c.item,c.integrity);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,HistoryActor>
void state_fields(A& a,V& c){a(c.entity,c.epoch,c.kind,c.position,c.yaw,c.pitch,c.alive);a.optional(c.armor);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,HistoryDoor>
void state_fields(A& a,V& c){a(c.entity,c.open,c.destroyed);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,HistoryFrame>
void state_fields(A& a,V& c){a(c.tick);a.sequence(c.actors,840);a.sequence(c.doors,512);}
}
