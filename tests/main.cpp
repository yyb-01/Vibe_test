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
        {"checkpoint recovery", checkpoint_recovery}, {"checkpoint corruption", checkpoint_corruption}
    };
    for (const auto& [name, run] : cases) {
        try { run(); std::cout << "PASS " << name << '\n'; }
        catch (const astra::Violation& e) { std::cerr << "FAIL " << name << ": " << astra::name(e.code) << '\n'; return 1; }
        catch (const std::exception& e) { std::cerr << "FAIL " << name << ": " << e.what() << '\n'; return 1; }
    }
    return 0;
}
