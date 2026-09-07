#include "scenario.hpp"
#include "checkpoint_wire.hpp"

void checkpoint_recovery() {
    Scenario s;
    auto before=s.inventory.snapshot();
    auto part=move(*before,id(100),id(20)); part.quantity=7;
    auto request=s.request(Operation::Split,{part});
    auto pending=s.inventory.prepare(request,s.access);
    auto candidate=s.inventory.checkpoint_after(pending.changes);
    CHECK(s.inventory.snapshot()==before);
    auto encoded=encode_checkpoint(candidate);
    Inventory recovered(decode_checkpoint(encoded));
    auto replay=recovered.apply(request,s.access);
    CHECK(replay.applied() && replay.sequence==1 && replay.created==pending.changes->outcome.created);
    CHECK(recovered.snapshot()->items.at(id(100)).quantity==13);
    CHECK(encode_checkpoint(recovered.checkpoint())==encoded);
    auto bad=request; bad.moves[0].quantity=6;
    CHECK(recovered.apply(bad,s.access).code==Error::IdempotencyMismatch);
    auto merge=s.request(Operation::Merge,{move(*recovered.snapshot(),replay.created,id(10),0)});
    CHECK(recovered.apply(merge,s.access).applied());
    auto denied=s.request(Operation::Move,{move(*recovered.snapshot(),id(100),id(20),UINT16_MAX)});
    CHECK(recovered.apply(denied,s.access).code==Error::InvalidPlacement);
    auto finalBytes=encode_checkpoint(recovered.checkpoint());
    Inventory again(decode_checkpoint(finalBytes));
    CHECK(again.apply(denied,s.access).code==Error::InvalidPlacement);
    CHECK(again.snapshot()->items.at(replay.created).flags & deleted);
    CHECK(again.snapshot()->items.at(id(100)).quantity==20);
    CHECK(!again.snapshot()->placements.contains(replay.created));
    auto next=s.request(Operation::Move,{move(*again.snapshot(),id(100),id(20))});
    CHECK(again.apply(next,s.access).sequence==3);
    CHECK(s.inventory.abort(pending.changes));
}

void checkpoint_corruption() {
    Scenario s;
    auto bytes=encode_checkpoint(s.inventory.checkpoint());
    for(std::size_t n=0;n<bytes.size();++n) {
        std::vector<std::uint8_t> cut(bytes.begin(),bytes.begin()+n);
        bool rejected=false;
        try { (void)decode_checkpoint(cut); } catch(const Violation&) { rejected=true; }
        CHECK(rejected);
    }
    for(std::size_t n=0;n<bytes.size();++n) {
        auto corrupt=bytes; corrupt[n]^=1;
        rejects([&]{ (void)decode_checkpoint(corrupt); },Error::InvalidState);
    }
    auto invalid=s.inventory.checkpoint(); invalid.nextId=1;
    rejects([&]{ (void)encode_checkpoint(invalid); },Error::InvalidState);
    invalid=s.inventory.checkpoint(); invalid.world.containers.at(id(10)).state.subtreeMassG=0;
    rejects([&]{ (void)encode_checkpoint(invalid); },Error::InvalidState);
    invalid=s.inventory.checkpoint(); invalid.sequence=1;
    rejects([&]{ (void)encode_checkpoint(invalid); },Error::InvalidState);
    auto badVersion=bytes; badVersion[4]=2;
    auto sum=checkpoint_wire::checksum(badVersion,badVersion.size()-8);
    for(unsigned i=0;i<8;++i) badVersion[badVersion.size()-8+i]=static_cast<std::uint8_t>(sum>>(8*i));
    rejects([&]{ (void)decode_checkpoint(badVersion); },Error::InvalidState);
}
