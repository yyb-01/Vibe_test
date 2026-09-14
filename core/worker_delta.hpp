#pragma once
#include "durable.hpp"

namespace astra {
// Worker-owned execution memory, never shared with the inventory owner.
struct WorkerDelta {
    // ponytail: full checkpoints stay on the worker until SQLite row storage replaces them.
    StoredWorld current;
    std::optional<Checkpoint> target;
    SaveOutcome finish(SaveOutcome outcome) {
        if (outcome == SaveOutcome::Committed) {
            current.checkpoint = std::move(*target); ++current.version;
        }
        if (outcome != SaveOutcome::Unknown) target.reset();
        return outcome;
    }
    SaveOutcome resolve(DurableStore& store) {
        require(target.has_value(), Error::InvalidState);
        auto loaded = store.inspect(); // Failure preserves the target for another inspect.
        if (loaded.checkpoint.epoch != target->epoch) return finish(SaveOutcome::Fenced);
        if (loaded.version == current.version) return finish(SaveOutcome::Aborted);
        if (loaded.version == current.version + 1 &&
            encode_checkpoint(loaded.checkpoint) == encode_checkpoint(*target))
            return finish(SaveOutcome::Committed);
        return finish(SaveOutcome::Fenced);
    }
    SaveOutcome save(DurableStore& store, std::uint64_t version, const CheckpointDelta& delta) {
        require(!target, Error::Busy);
        if (version != current.version || version == revision_limit || delta.changes.epoch != current.checkpoint.epoch)
            return SaveOutcome::Fenced;
        try {
            auto staged = current.checkpoint;
            apply_checkpoint_delta(staged, delta);
            target = std::move(staged);
        } catch (const Violation& e) {
            return e.code == Error::LimitExceeded ? SaveOutcome::Limited : SaveOutcome::Aborted;
        } catch (...) { return SaveOutcome::Aborted; }
        SaveOutcome outcome = SaveOutcome::Unknown;
        try { outcome = store.save(version, *target, target->requests.back()); } catch (...) {}
        return outcome == SaveOutcome::Unknown ? resolve(store) : finish(outcome);
    }
};
}
