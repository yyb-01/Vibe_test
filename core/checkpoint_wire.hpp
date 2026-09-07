#pragma once
#include "wire.hpp"
#include "checkpoint.hpp"

namespace astra::checkpoint_wire {
inline void put(Writer& w, const ItemDef& d) {
    for (auto n : {d.id, d.massG, d.outerVolumeMl, d.maxStack}) w.put(n, 4);
    for (auto n : {d.gridW, d.gridH, d.classId, d.materialId}) w.put(n, 2);
    for (auto n : {d.containerDefId, d.partDefId, d.assetId, d.flags}) w.put(n, 4);
}
inline ItemDef definition(Reader& r) {
    ItemDef d;
    d.id=r.get(4); d.massG=r.get(4); d.outerVolumeMl=r.get(4); d.maxStack=r.get(4);
    d.gridW=r.get(2); d.gridH=r.get(2); d.classId=r.get(2); d.materialId=r.get(2);
    d.containerDefId=r.get(4); d.partDefId=r.get(4); d.assetId=r.get(4); d.flags=r.get(4);
    return d;
}
inline void put(Writer& w, const ItemState& i) {
    w.id(i.id); w.put(i.revision,8); w.put(i.defId,4); w.put(i.quantity,4);
    w.put(i.extraIndex,4); w.put(i.flags,4);
    for (auto n : {i.durability,i.contamination,i.wetness,i.temperatureOffset}) w.put(n,2);
    w.put(i.birthEvent,8); w.put(i.reservedBy,8);
}
inline ItemState item(Reader& r) {
    ItemState i; i.id=r.id(); i.revision=r.get(8); i.defId=r.get(4); i.quantity=r.get(4);
    i.extraIndex=r.get(4); i.flags=r.get(4); i.durability=r.get(2); i.contamination=r.get(2);
    i.wetness=r.get(2); i.temperatureOffset=r.get(2); i.birthEvent=r.get(8); i.reservedBy=r.get(8);
    return i;
}
inline void put(Writer& w, const Container& c) {
    const auto& s=c.state; w.id(s.id); w.id(s.ownerItem); w.put(s.revision,8); w.put(s.subtreeMassG,8);
    w.put(s.usedVolumeMl,4); w.put(s.capacityMl,4); w.put(s.width,2); w.put(s.height,2);
    w.put(s.entryCount,2); w.put(s.depth,1); w.put(s.flags,1);
    w.put(c.maxMassG,8); w.put(c.allowedClasses,8); w.put(static_cast<unsigned>(c.kind),1);
}
inline Container container(Reader& r) {
    Container c; auto& s=c.state; s.id=r.id(); s.ownerItem=r.id(); s.revision=r.get(8); s.subtreeMassG=r.get(8);
    s.usedVolumeMl=r.get(4); s.capacityMl=r.get(4); s.width=r.get(2); s.height=r.get(2);
    s.entryCount=r.get(2); s.depth=r.get(1); s.flags=r.get(1);
    c.maxMassG=r.get(8); c.allowedClasses=r.get(8); c.kind=static_cast<PlaceKind>(r.get(1));
    return c;
}
inline void put(Writer& w, const Placement& p) {
    w.id(p.item); w.id(p.container); w.put(p.socketId,4); w.put(p.x,2); w.put(p.y,2);
    w.put(p.rotation,1); w.put(static_cast<unsigned>(p.kind),1); w.put(p.reserved,2); w.put(p.ordinal,4);
}
inline Placement placement(Reader& r) {
    Placement p; p.item=r.id(); p.container=r.id(); p.socketId=r.get(4); p.x=r.get(2); p.y=r.get(2);
    p.rotation=r.get(1); p.kind=static_cast<PlaceKind>(r.get(1)); p.reserved=r.get(2); p.ordinal=r.get(4);
    return p;
}
inline std::uint64_t checksum(const std::vector<std::uint8_t>& bytes, std::size_t size) {
    std::uint64_t h=14695981039346656037ULL;
    for (std::size_t i=0;i<size;++i) { h^=bytes[i]; h*=1099511628211ULL; }
    return h; // Corruption check only, not an authenticity or cryptographic hash.
}
}
