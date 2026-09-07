#include "inventory.hpp"

namespace astra {
void validate_catalog(const Catalog& catalog) {
    require(!catalog.empty() && catalog.size() <= 65536, Error::InvalidState);
    for (const auto& [id, d] : catalog) {
        require(id && id <= INT32_MAX && d.id == id, Error::InvalidState);
        require(d.maxStack && d.gridW && d.gridH && d.gridW <= 32 && d.gridH <= 32,
                Error::InvalidState);
        require(d.classId < 64, Error::InvalidState);
        require(!(d.containerDefId || d.partDefId) || d.maxStack == 1, Error::InvalidState);
    }
}
}
