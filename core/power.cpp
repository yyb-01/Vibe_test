#include "power.hpp"
#include "fixed_math.hpp"
#include <set>
namespace astra {
EnergyBatch allocate_power(PowerGrid& grid,std::uint32_t us) {
    require(us&&us<=1000000&&grid.nodes.size()<=10000&&grid.cables.size()<=20000,Error::InvalidRequest);
    auto next=grid;EnergyBatch result;std::map<Id,std::vector<Id>> adjacent;std::set<std::pair<Id,Id>> edges;
    auto fraction=[](std::uint64_t n,std::uint16_t q){return std::uint64_t(fixed::mul_div(std::int64_t(n),q,65535));};
    for(const auto& [id,n]:next.nodes) {
        require(id&&id==n.entity&&finite(n.position)&&n.batteryUj<=n.capacityUj&&n.capacityUj<=100000000000000ULL&&n.chargeEfficiency&&n.dischargeEfficiency,Error::InvalidState);
        for(auto w:{n.generateW,n.demandW,n.chargeW,n.dischargeW})require(w<=1000000,Error::InvalidState);
        result.initialBatteryUj+=n.batteryUj;
    }
    for(auto e:next.cables) {
        require(e.a!=e.b&&next.nodes.contains(e.a)&&next.nodes.contains(e.b)&&edges.emplace(std::min(e.a,e.b),std::max(e.a,e.b)).second,Error::InvalidState);
        bounded(e.maxLengthM,.01,1000);require(length(next.nodes.at(e.a).position-next.nodes.at(e.b).position)<=e.maxLengthM,Error::InvalidPlacement);
        adjacent[e.a].push_back(e.b);adjacent[e.b].push_back(e.a);
    }
    std::set<Id> visited;
    for(const auto& [root,unused]:next.nodes) {
        (void)unused;if(!visited.insert(root).second)continue;
        std::vector<Id> component{root};std::size_t edgeCount=0;
        for(std::size_t i=0;i<component.size();++i) {
            for(auto other:adjacent[component[i]]){++edgeCount;if(visited.insert(other).second)component.push_back(other);}
            require(component.size()<=256&&edgeCount<=1024,Error::LimitExceeded);
        }
        std::sort(component.begin(),component.end(),[&](Id a,Id b){auto pa=next.nodes.at(a).priority,pb=next.nodes.at(b).priority;return pa!=pb?pa<pb:a<b;});
        std::uint64_t supply=0,demand=0;std::set<Id> discharged;
        for(auto id:component) {
            auto& n=next.nodes.at(id);auto made=std::uint64_t(n.generateW)*us;
            if(!n.renewable){made=std::min(made,n.fuelUj);n.fuelUj-=made;}
            supply+=made;result.generatedUj+=made;demand+=std::uint64_t(n.demandW)*us;
        }
        for(auto id:component) {
            if(supply>=demand)break;auto& n=next.nodes.at(id);
            auto take=std::min({n.batteryUj,std::uint64_t(n.dischargeW)*us,std::uint64_t(fixed::mul_div(std::int64_t(demand-supply),65535,n.dischargeEfficiency))+1});
            if(!take)continue;auto delivered=fraction(take,n.dischargeEfficiency);n.batteryUj-=take;supply+=delivered;result.lossUj+=take-delivered;discharged.insert(id);
        }
        for(auto id:component) {
            auto& n=next.nodes.at(id);auto need=std::uint64_t(n.demandW)*us;
            auto delivered=n.partial?std::min(supply,need):(supply>=need?need:0);
            result.deliveredUj[id]=delivered;supply-=delivered;result.loadUj+=delivered;
        }
        for(auto id:component) {
            auto& n=next.nodes.at(id);if(discharged.contains(id))continue;
            auto input=std::min({supply,std::uint64_t(n.chargeW)*us,std::uint64_t(fixed::mul_div(std::int64_t(n.capacityUj-n.batteryUj),65535,n.chargeEfficiency))});
            auto stored=fraction(input,n.chargeEfficiency);require(stored<=n.capacityUj-n.batteryUj,Error::InvalidState);
            n.batteryUj+=stored;supply-=input;result.lossUj+=input-stored;
        }
        result.unusedUj+=supply;
    }
    for(const auto& [id,n]:next.nodes){(void)id;result.finalBatteryUj+=n.batteryUj;}
    require(result.initialBatteryUj+result.generatedUj==result.finalBatteryUj+result.loadUj+result.lossUj+result.unusedUj,Error::InvalidState);
    grid=std::move(next);return result;
}
}
