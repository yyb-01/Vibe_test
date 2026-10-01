#include "game_command.hpp"
#include "state_survival.hpp"
namespace astra {
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,GameCommand>
void state_fields(A& a,V& c){a(c.id,c.operation,c.lifeEpoch,c.sequence,c.definition,c.quantity,c.targets,c.position,c.tick,c.revision,c.event,
    c.yaw,c.pitch,c.gear,c.throttle,c.brake,c.steer,c.enabled);}
static void shape(const GameCommand& c) {
    require(c.id&&unsigned(c.operation)<=unsigned(GameOperation::Lock)&&c.lifeEpoch&&c.quantity&&c.quantity<=1000000&&
        finite(c.position)&&c.pitch>=-16384&&c.pitch<=16384&&c.gear>=0&&c.gear<16&&c.tick<=revision_limit/65536,Error::InvalidRequest);
    bounded(c.throttle,-1,1);bounded(c.brake,0,1);bounded(c.steer,-1,1);
}
std::vector<std::uint8_t> encode_command(const GameCommand& c) {
    shape(c);StateSave a;a.writer.put(1,2);a(c);return std::move(a.writer.bytes);
}
GameCommand decode_command(const std::vector<std::uint8_t>& bytes) {
    require(bytes.size()<=512,Error::InvalidRequest);StateLoad a{{bytes}};
    require(a.reader.get(2)==1,Error::Incompatible);GameCommand c;a(c);
    require(a.reader.position==bytes.size(),Error::InvalidRequest);shape(c);return c;
}
}
