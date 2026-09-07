#include "checkpoint_wire.hpp"

namespace astra {
std::vector<std::uint8_t> encode_checkpoint(const Checkpoint& c) {
    validate_checkpoint(c);
    Writer w; w.put(0x41525453,4); w.put(1,4);
    for(auto n:{c.epoch,c.origin,c.sequence,c.nextId,c.nextEvent}) w.put(n,8);
    w.put(c.catalog.size(),4);
    for(const auto& [id,d]:c.catalog) { (void)id; checkpoint_wire::put(w,d); }
    w.put(c.world.items.size(),4);
    for(const auto& [id,i]:c.world.items) { (void)id; checkpoint_wire::put(w,i); }
    w.put(c.world.containers.size(),4);
    for(const auto& [id,container]:c.world.containers) { (void)id; checkpoint_wire::put(w,container); }
    w.put(c.world.placements.size(),4);
    for(const auto& [id,p]:c.world.placements) { (void)id; checkpoint_wire::put(w,p); }
    w.put(c.requests.size(),4);
    for(const auto& q:c.requests) {
        w.id(q.account); w.id(q.requestId); w.put(q.actionSeq,8); w.put(q.payload.size(),4);
        w.bytes.insert(w.bytes.end(),q.payload.begin(),q.payload.end());
        w.put(static_cast<unsigned>(q.result.code),4); w.put(q.result.sequence,8); w.id(q.result.created);
    }
    w.put(checkpoint_wire::checksum(w.bytes,w.bytes.size()),8);
    require(w.bytes.size()<=checkpoint_byte_limit,Error::LimitExceeded);
    return std::move(w.bytes);
}
Checkpoint decode_checkpoint(const std::vector<std::uint8_t>& bytes) {
    require(bytes.size()>=76 && bytes.size()<=checkpoint_byte_limit,Error::InvalidState);
    Reader tail{bytes,bytes.size()-8};
    require(tail.get(8)==checkpoint_wire::checksum(bytes,bytes.size()-8),Error::InvalidState);
    Reader r{bytes};
    require(r.get(4)==0x41525453 && r.get(4)==1,Error::InvalidState);
    Checkpoint c; c.epoch=r.get(8); c.origin=r.get(8); c.sequence=r.get(8); c.nextId=r.get(8); c.nextEvent=r.get(8);
    auto count=[&](std::size_t limit) { auto n=r.get(4); require(n<=limit,Error::LimitExceeded); return n; };
    for(auto n=count(65536);n;--n) { auto d=checkpoint_wire::definition(r); require(c.catalog.emplace(d.id,d).second,Error::InvalidState); }
    for(auto n=count(65536);n;--n) { auto i=checkpoint_wire::item(r); require(c.world.items.emplace(i.id,i).second,Error::InvalidState); }
    for(auto n=count(4096);n;--n) { auto v=checkpoint_wire::container(r); require(c.world.containers.emplace(v.state.id,v).second,Error::InvalidState); }
    for(auto n=count(65536);n;--n) { auto p=checkpoint_wire::placement(r); require(c.world.placements.emplace(p.item,p).second,Error::InvalidState); }
    for(auto n=count(65536);n;--n) {
        SavedRequest q; q.account=r.id(); q.requestId=r.id(); q.actionSeq=r.get(8);
        auto length=count(748);
        require(length<=bytes.size()-r.position,Error::InvalidState);
        q.payload.assign(bytes.begin()+r.position,bytes.begin()+r.position+length); r.position+=length;
        q.result.code=static_cast<Error>(r.get(4)); q.result.sequence=r.get(8); q.result.created=r.id();
        c.requests.push_back(std::move(q));
    }
    require(r.position==bytes.size()-8,Error::InvalidState);
    validate_checkpoint(c);
    return c;
}
}
