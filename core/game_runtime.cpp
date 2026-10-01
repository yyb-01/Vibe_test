#include "game_command.hpp"
namespace astra {
GameRuntime::GameRuntime(DurableInventory& inventory,GameDefinitions defs):inventory_(inventory),definitions_(std::move(defs)) {
    validate_definitions(definitions_);auto rows=inventory_.snapshot();validate_game_world(definitions_,*rows,state());
}
GameState GameRuntime::state() const {
    auto rows=inventory_.snapshot();auto& root=rows->containers.at(game_root);std::lock_guard lock(cacheMutex_);
    if(!cached_||cachedRevision_!=root.state.revision){auto state=decode_game(root.gameplay);cached_=std::move(state);cachedRevision_=root.state.revision;}
    return *cached_;
}
Result GameRuntime::dispatch(const GameCommand& command,const GamePeer& peer) {
    auto sequence=inventory_.snapshot_roots({}).sequence;
    try {
        require(peer.account&&(!peer.host||peer.account==simulation_account),Error::NotAccessible);
        auto admitted=state();
        require(peer.host ? command.operation==GameOperation::Tick :
            admitted.lives.contains(peer.actor)&&admitted.lives.at(peer.actor).account==peer.account,
            Error::NotAccessible);
        auto payload=encode_command(command);Request r;
        if(auto old=inventory_.recorded_request(peer.account,command.id)) {
            require(old->operation==Operation::System&&old->command==payload,Error::IdempotencyMismatch);r=*old;
        } else {
            require(!inventory_.expired_input(peer.account,command.id),Error::SequenceMismatch);
            auto w=inventory_.snapshot();
            r.id=command.id;r.operation=Operation::System;r.actionSeq=inventory_.next_action_sequence(peer.account);
            r.baseline=sequence;r.interactionLease=1;r.command=std::move(payload);
            // ponytail: the authority blob serializes simulation; split by cell after measured contention.
            for(auto& [id,c]:w->containers)if(!c.state.ownerItem)r.systemRoots.push_back(id);
            require(r.systemRoots.size()<=32,Error::LimitExceeded);
            r.newIds=game_allocation_budget(definitions_,admitted,command);
            r.mutation=[this,command,peer,count=r.newIds](World& rows,Id first,std::uint64_t event){
                auto state=decode_game(rows.containers.at(game_root).gameplay);GameIds ids{first,count};
                require(state.catalogVersion==definitions_.version,Error::Incompatible);
                execute_game(definitions_,rows,state,command,peer,ids,event);
                ++state.revision;rows.containers.at(game_root).gameplay=encode_game(state);
            };
        }
        Access access{peer.account,inventory_.epoch(),1,{r.systemRoots.begin(),r.systemRoots.end()}};
        access.approvedSystem=encode(r);return inventory_.apply(r,access);
    } catch(const Violation& e){return {e.code,sequence,{}};}
}
}
