#include "beam_scene.hpp"
#include "ballistic_geometry.hpp"
#include "fixed_math.hpp"
namespace astra {
ballistics::Atmosphere ammunition_air(const AmmoProfile& ammo,const ballistics::Vector& velocity) {
    auto speed=ballistics::detail::length({},velocity);auto mach=std::uint32_t(fixed::mul_div(speed,65536,ammo.soundSpeedUmS));
    auto hi=std::upper_bound(ammo.dragMach.begin(),ammo.dragMach.end(),mach,[](auto m,auto& row){return m<row.first;});
    std::int64_t drag=hi==ammo.dragMach.begin()?hi->second:std::prev(hi)->second;
    if(hi!=ammo.dragMach.begin()&&hi!=ammo.dragMach.end()) {
        auto lo=std::prev(hi);drag+=fixed::mul_div(std::int64_t(hi->second)-lo->second,mach-lo->first,hi->first-lo->first);
    }
    require(drag>=0&&drag<=10000,Error::InvalidState);ballistics::Atmosphere air;air.dragPpt=std::uint32_t(drag);return air;
}
}
