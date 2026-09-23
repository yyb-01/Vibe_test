#include <iostream>
#include "check.hpp"
void transactions(); void swaps_and_world(); void rejections();
void capacity_and_conditions(); void concurrent_loot(); void randomized_conservation(); void wire_contract();
void grid_and_tree_boundaries(); void overflow_and_state();
void prepared_lifecycle(); void prepared_abort(); void prepared_rejections();
void write_set_contents(); void prepared_concurrency();
void disjoint_commit_order(); void root_reservations(); void concurrent_disjoint_roots();
void pending_account_limit(); void partial_copy_item_limit();
void root_snapshot_sharing(); void allocation_free_publication();
void prepare_allocation_rollback(); void concurrent_root_snapshots();
void checkpoint_recovery(); void checkpoint_corruption();
void async_publication(); void async_resolution(); void async_limits(); void async_rollback();
void account_sequence();
void validation_paths();
void checkpoint_deltas(); void async_deltas();
void packet_contract(); void packet_window();
void session_admission(); void transaction_budget(); void session_commands();
void session_rate_limits(); void session_shutdown();
void session_leases(); void session_lease_expiry(); void session_lease_replay();
void request_results();
void receipt_contract(); void receipt_validation(); void receipt_reasons(); void session_receipts();
void snapshot_wire(); void snapshot_pages_test(); void session_snapshots();
void client_requests(); void client_snapshots();
void client_publication();
void client_reconnect(); void client_restart();
void reconnect_codec();
void console_shutdown();
void shutdown_codec(); void client_shutdown();
void stream_frames(); void stream_session();
void transport_session(); void transport_failures();
void client_transport_session(); void client_transport_failures(); void transport_shutdown();
void snapshot_control(); void transport_snapshots(); void transport_snapshot_failures(); void transport_snapshot_pages();
void transport_deadlines(); void client_transport_deadlines(); void snapshot_transport_deadlines();
void transport_loop(); void transport_loop_failures();
void multiplayer_lifecycle(); void multiplayer_transactions();
void console_input();
int main() {
    const std::pair<const char*, void(*)()> cases[]{
        {"transactions", transactions}, {"swaps and world", swaps_and_world},
        {"rejections", rejections}, {"capacity and conditions", capacity_and_conditions},
        {"20 concurrent looters", concurrent_loot}, {"1000 conserved transactions", randomized_conservation},
        {"wire contract", wire_contract}, {"grid and tree boundaries", grid_and_tree_boundaries},
        {"overflow and invalid state", overflow_and_state},
        {"prepared lifecycle", prepared_lifecycle}, {"prepared abort", prepared_abort},
        {"prepared rejections", prepared_rejections}, {"write-set contents", write_set_contents},
        {"20 concurrent prepare and commit", prepared_concurrency},
        {"disjoint commit order", disjoint_commit_order}, {"root reservations", root_reservations},
        {"20 independent roots", concurrent_disjoint_roots},
        {"pending account limit", pending_account_limit}, {"partial copy and global item limit", partial_copy_item_limit},
        {"root snapshot sharing", root_snapshot_sharing}, {"allocation-free publication", allocation_free_publication},
        {"prepare allocation rollback", prepare_allocation_rollback}, {"concurrent root snapshots", concurrent_root_snapshots},
        {"checkpoint recovery", checkpoint_recovery}, {"checkpoint corruption", checkpoint_corruption},
        {"async owner publication", async_publication}, {"async uncertain shutdown", async_resolution},
        {"async queue limits", async_limits}, {"async rollback retry", async_rollback},
        {"account sequence recovery", account_sequence}, {"validation paths", validation_paths},
        {"checkpoint deltas", checkpoint_deltas}, {"async delta publication", async_deltas},
        {"packet contract", packet_contract}, {"packet window", packet_window},
        {"session admission", session_admission}, {"transaction budget", transaction_budget},
        {"session commands", session_commands}, {"session rate limits", session_rate_limits},
        {"session shutdown", session_shutdown}, {"session leases", session_leases},
        {"session lease expiry", session_lease_expiry}, {"session lease replay", session_lease_replay},
        {"request result lookup", request_results}, {"receipt contract", receipt_contract},
        {"receipt validation", receipt_validation}, {"receipt reasons", receipt_reasons},
        {"session receipts", session_receipts}, {"snapshot wire", snapshot_wire},
        {"snapshot pages", snapshot_pages_test}, {"session snapshots", session_snapshots},
        {"client requests", client_requests}, {"client snapshots", client_snapshots},
        {"client atomic publication", client_publication},
        {"client reconnect", client_reconnect}, {"client restart", client_restart},
        {"reconnect codec", reconnect_codec}, {"console shutdown retry", console_shutdown},
        {"shutdown codec", shutdown_codec}, {"client shutdown notification", client_shutdown},
        {"stream frames", stream_frames}, {"stream session", stream_session},
        {"transport session", transport_session}, {"transport failures", transport_failures},
        {"client transport session", client_transport_session},
        {"client transport failures", client_transport_failures}, {"transport shutdown", transport_shutdown},
        {"snapshot control", snapshot_control}, {"transport snapshots", transport_snapshots},
        {"transport snapshot failures", transport_snapshot_failures}, {"transport snapshot pages", transport_snapshot_pages},
        {"transport deadlines", transport_deadlines}, {"client transport deadlines", client_transport_deadlines},
        {"snapshot transport deadlines", snapshot_transport_deadlines},
        {"transport loop", transport_loop}, {"transport loop failures", transport_loop_failures},
        {"20-player transport lifecycle", multiplayer_lifecycle},
        {"20-player transport transactions", multiplayer_transactions},
        {"console input tick", console_input}
    };
    for (const auto& [name, run] : cases) {
        try { run(); std::cout << "PASS " << name << '\n'; }
        catch (const astra::Violation& e) { std::cerr << "FAIL " << name << ": " << astra::name(e.code) << '\n'; return 1; }
        catch (const std::exception& e) { std::cerr << "FAIL " << name << ": " << e.what() << '\n'; return 1; }
    }
    return 0;
}
