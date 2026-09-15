#include "session.hpp"

namespace astra {
ResumeState HostSession::resume_state(std::uint64_t connection) {
    owner(); auto& p = admit_command(connection);
    return {{info_.world, p.account, info_.catalogHash}, info_.epoch,
            inventory_.snapshot_roots({}).sequence, inventory_.next_action_sequence(p.account)};
}
}
