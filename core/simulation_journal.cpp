#include "simulation_journal.hpp"
#include "game_command.hpp"
#include <algorithm>
namespace astra {
bool simulation_request(const Request& r) {
    return r.operation==Operation::System&&decode_command(r.command).operation==GameOperation::Tick;
}
bool input_request(const Request& r){
    if(r.operation!=Operation::System)return false;
    try{auto op=decode_command(r.command).operation;return op==GameOperation::Move||op==GameOperation::Aim||op==GameOperation::Drive;}
    catch(const Violation&){return false;}
}
void compact_simulation(Checkpoint& c) {
    std::uint64_t latest=0;
    for(auto& r:c.requests)if(r.account==simulation_account) {
        require(simulation_request(decode(r.payload)),Error::InvalidState);latest=std::max(latest,r.actionSeq);
    }
    // Internal ticks have no remote retries. Economic receipts remain replayable.
    std::erase_if(c.requests,[&](const SavedRequest& r){
        if(r.account!=simulation_account||r.actionSeq==latest)return false;
        ++c.retiredRequests;c.retiredCommits+=r.result.applied();return true;
    });
    std::map<Id,std::vector<std::uint64_t>> inputs;
    for(auto& r:c.requests)if(input_request(decode(r.payload))){
        require(r.requestId.lo,Error::InvalidState);inputs[r.account].push_back(r.actionSeq);
        c.retiredInputs[r.account].floors.try_emplace(r.requestId.hi,0);
    }
    std::map<Id,std::uint64_t> cutoff;
    // ponytail: 32 input receipts/account; expired inputs fail rather than replay. Economic effects are never expired.
    for(auto& [account,actions]:inputs)if(actions.size()>32){std::sort(actions.begin(),actions.end());cutoff[account]=actions[actions.size()-33];}
    std::erase_if(c.requests,[&](const SavedRequest& r){
        if(!cutoff.contains(r.account)||r.actionSeq>cutoff.at(r.account)||!input_request(decode(r.payload)))return false;
        auto& journal=c.retiredInputs.at(r.account);++journal.retired;c.retiredCommits+=r.result.applied();
        auto& floor=journal.floors.at(r.requestId.hi);floor=std::max(floor,r.requestId.lo);return true;
    });
}
}
