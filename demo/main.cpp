#include "console.hpp"
#include <iostream>
#include <sstream>

int main(int argc, char** argv) {
    bool smoke = argc == 2 && std::string(argv[1]) == "--smoke";
    Scenario scenario;
    Request previous; bool hasPrevious = false;
    std::istringstream script(
        "show\ntake 100 4 0\nsplit 100 7 20 5 0\nreplay\nmerge 105 20 4 0\n"
        "drop 100\ntake 100 4 0\nswap 102 104\nshow\nquit\n");
    auto& input = smoke ? static_cast<std::istream&>(script) : std::cin;
    std::cout << "ASTRA inventory sandbox (memory only; no game rendering or durable save)\n"
              << "10=chest 20=player bag 30=ground 40=nested pouch\n"
              << "show | take ITEM X Y | drop ITEM | move ITEM CONTAINER X Y\n"
              << "split ITEM COUNT CONTAINER X Y | merge ITEM CONTAINER X Y\n"
              << "swap ITEM ITEM | replay | quit\n";
    std::string line;
    for (;;) {
        if (!smoke) std::cout << "> " << std::flush;
        if (!std::getline(input, line) || line == "quit") break;
        try {
            if (!command(scenario, line, previous, hasPrevious) && smoke) return 1;
        } catch (const Violation& e) {
            std::cerr << name(e.code) << '\n'; if (smoke) return 1;
        } catch (const std::exception& e) {
            std::cerr << e.what() << '\n'; if (smoke) return 1;
        }
    }
    return 0;
}
