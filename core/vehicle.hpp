#pragma once
#include "sim_math.hpp"
#include "types.hpp"
#include <vector>
#include <span>
namespace astra {
struct MassPart {
    Id item; double massKg{}; Vec3 com; Mat3 inertia,rotation{diagonal(1,1,1)};
};
struct MassProperties { double massKg{}; Vec3 com; Mat3 inertia; };
MassProperties combine_mass(std::vector<MassPart>);
struct DetachedMotion { Vec3 chassisVelocity,chassisOmega,partVelocity,partOmega; MassProperties remaining; };
DetachedMotion detach_part(const std::vector<MassPart>&,Id,Vec3 velocity,Vec3 omega);
struct WheelDef {
    Vec3 anchor;
    double radius{.35},restLength{.4},travel{.3},stiffness{30000},damping{3000},maxForce{30000};
    double inertia{1},muX{.9},muY{.9},longitudinal{18000},lateral{20000},rolling{.01};
};
struct WheelContact {
    bool hit{},sweep{};double distance{},forwardSpeed{},sideSpeed{};
    Vec3 normal{0,0,1},forward{1,0,0};
};
struct Wheel { double omega{},steer{},compression{},slipRatio{},slipAngle{},temperatureK{293.15},wear{}; bool punctured{},attached{true}; };
struct WheelForce { Vec3 force,point; double load{}; };
WheelForce wheel_force(Wheel&,const WheelDef&,const WheelContact&,double driveNm,double brakeNm,double dt);
struct EngineDef {
    std::vector<std::pair<double,double>> torqueCurve{{800,100},{3000,250},{6000,180}};
    double inertia{.3},idleRpm{800},redlineRpm{6000},clutchNm{500},finalRatio{3.5},efficiency{.9};
    std::vector<double> gears{-3.2,0,3.2,2.1,1.5,1};
};
struct Vehicle {
    Id entity,driver;std::uint64_t revision{1},assemblyRevision{1},tick{};
    std::uint32_t inputSeq{},physicsRevision{1};
    Vec3 position,velocity,omega;Mat3 rotation{diagonal(1,1,1)};
    double engineRpm{800},clutch{1},steer{},fuelResidual{},batteryResidual{};
    std::uint64_t fuelUl{10000000},batteryMilliJ{36000000};
    std::int8_t gear{2};std::uint8_t drivenMask{15};bool running{},torquePath{true};
    std::vector<MassPart> parts{};std::vector<Wheel> wheels{};
};
struct DriveInput { std::uint32_t sequence{};std::uint64_t tick{},assemblyRevision{};double throttle{},brake{},steer{};std::int8_t gear{2}; };
struct VehicleForces { Vec3 force,torque; std::vector<WheelForce> wheels; };
VehicleForces drive(Vehicle&,const EngineDef&,std::span<const WheelDef>,std::span<const WheelContact>,const DriveInput&,Id account);
}
