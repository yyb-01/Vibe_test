#include "host.hpp"
namespace astra::native {
GameCommand remote_fire(std::istringstream& input,Id request,std::uint64_t epoch,bool recorded){
    std::string verb,item,extra;std::uint64_t submittedEpoch;int yaw,pitch;
    GameCommand c;c.id=request;c.operation=GameOperation::Fire;
    require(bool(input>>verb>>item>>submittedEpoch>>c.tick>>c.lifeEpoch>>c.revision>>c.sequence>>c.event>>yaw>>pitch)&&!(input>>extra),Error::InvalidRequest);
    require(submittedEpoch==epoch||recorded,Error::EpochMismatch);
    require(c.tick<=UINT32_MAX&&c.event&&c.event<=UINT32_MAX&&c.sequence&&yaw>=-32768&&yaw<=32767&&pitch>=-16384&&pitch<=16384,Error::InvalidRequest);
    c.targets[0]=parse_id(item);c.yaw=std::int16_t(yaw);c.pitch=std::int16_t(pitch);return c;
}
}
