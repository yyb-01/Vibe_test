#pragma once
#include <string_view>

namespace astra {
enum class Error {
    Ok, InvalidRequest, NotAccessible, EpochMismatch, SequenceMismatch,
    IdempotencyMismatch, RevisionConflict, InvalidQuantity, InvalidPlacement,
    CapacityExceeded, CycleDetected, DepthExceeded, InvalidState, Incompatible,
    LimitExceeded, Pending, Busy, StorageUnavailable
};
struct Violation { Error code; };
inline void require(bool condition, Error code) {
    if (!condition) throw Violation{code};
}
inline std::string_view name(Error code) {
    constexpr std::string_view names[]{
        "Ok", "InvalidRequest", "NotAccessible", "EpochMismatch", "SequenceMismatch",
        "IdempotencyMismatch", "RevisionConflict", "InvalidQuantity", "InvalidPlacement",
        "CapacityExceeded", "CycleDetected", "DepthExceeded", "InvalidState", "Incompatible",
        "LimitExceeded", "Pending", "Busy", "StorageUnavailable"
    };
    auto index = static_cast<unsigned>(code);
    return index < sizeof(names) / sizeof(*names) ? names[index] : "Unknown";
}
}
