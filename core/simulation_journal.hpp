#pragma once
#include "checkpoint.hpp"
#include "simulation_identity.hpp"
namespace astra {
bool simulation_request(const Request&);
bool input_request(const Request&);
void compact_simulation(Checkpoint&);
inline std::uint64_t retired_count(const Checkpoint& c){
    auto total=c.retiredRequests;require(total<=revision_limit,Error::InvalidState);
    for(auto& [id,j]:c.retiredInputs){(void)id;require(j.retired<=revision_limit-total,Error::InvalidState);total+=j.retired;}return total;
}
inline std::uint64_t request_count(const Checkpoint& c){auto retired=retired_count(c);require(c.requests.size()<=revision_limit-retired,Error::InvalidState);return retired+c.requests.size();}
}
