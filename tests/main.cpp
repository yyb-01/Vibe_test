#include <iostream>
#include "check.hpp"
void transactions(); void swaps_and_world(); void rejections();
void capacity_and_conditions(); void concurrent_loot(); void randomized_conservation(); void wire_contract();
void grid_and_tree_boundaries(); void overflow_and_state();
int main() {
    const std::pair<const char*, void(*)()> cases[]{
        {"transactions", transactions}, {"swaps and world", swaps_and_world},
        {"rejections", rejections}, {"capacity and conditions", capacity_and_conditions},
        {"20 concurrent looters", concurrent_loot}, {"1000 conserved transactions", randomized_conservation},
        {"wire contract", wire_contract}, {"grid and tree boundaries", grid_and_tree_boundaries},
        {"overflow and invalid state", overflow_and_state}
    };
    for (const auto& [name, run] : cases) {
        try { run(); std::cout << "PASS " << name << '\n'; }
        catch (const astra::Violation& e) { std::cerr << "FAIL " << name << ": " << astra::name(e.code) << '\n'; return 1; }
        catch (const std::exception& e) { std::cerr << "FAIL " << name << ": " << e.what() << '\n'; return 1; }
    }
    return 0;
}
