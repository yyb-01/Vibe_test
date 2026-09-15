#include "console.hpp"
#include "shutdown.hpp"
#include <iostream>
#include <sstream>

#ifdef _WIN32
int wmain(int argc, wchar_t** argv) {
#else
int main(int argc, char** argv) {
#endif
    auto option = argc > 1 ? std::filesystem::path(argv[1]) : std::filesystem::path{};
    bool smoke = argc == 2 && option == "--smoke";
    bool clientMode = argc == 3 && option == "--client";
    std::filesystem::path save;
    if (argc == 3 && (option == "--save" || clientMode)) save = argv[2];
    else if (argc != 1 && !smoke && !(argc == 4 && option == "--restore")) {
        std::cerr << "Usage: astra-demo [--smoke | --save PATH | --client PATH | --restore BACKUP NEW_PATH]\n"; return 1;
    }
    try {
        if (argc == 4) { restore(argv[2], argv[3]); return 0; }
        if (argc == 3 && save.empty()) throw std::runtime_error("Save path must not be empty.");
        Session session(save, clientMode);
        if (clientMode) std::cout << "Client protocol mode: in-process only; fixed scene, no network authentication.\n";
        Request previous; bool hasPrevious = false;
        std::istringstream script(
            "show\ntake 100 4 0\nsplit 100 7 20 5 0\nreplay\nmerge 105 20 4 0\n"
            "drop 100\ntake 100 4 0\nswap 102 104\nshow\nquit\n");
        auto& input = smoke ? static_cast<std::istream&>(script) : std::cin;
        std::cout << "ASTRA inventory sandbox (" << (session.persistent() ? "SQLite async save" : "memory only") << ")\n"
                  << "10=chest 20=player bag 30=ground 40=nested pouch; IDs accept HI:LO\n"
                  << "show | take ITEM X Y | drop ITEM | move ITEM CONTAINER X Y\n"
                  << "split ITEM COUNT CONTAINER X Y | merge ITEM CONTAINER X Y\n"
                  << "swap ITEM ITEM | replay | resolve | quit\n"
                  << "ClientMode: disconnect | reconnect | submit COMMAND (no wait)\n";
        std::string line;
        int exitCode = 0;
        for (;;) {
            if (!smoke) std::cout << "> " << std::flush;
            bool eof = !std::getline(input, line);
            if (eof || line == "quit" || exitCode) {
                if (try_shutdown([&] { return session.close(); }, std::cerr)) return exitCode;
                if (eof || smoke) return 1;
                continue;
            }
            try {
                if (!command(session, line, previous, hasPrevious) && smoke) exitCode = 1;
            } catch (const Violation& e) {
                std::cerr << name(e.code) << '\n'; if (smoke) exitCode = 1;
            } catch (const std::exception& e) {
                std::cerr << e.what() << '\n'; if (smoke) exitCode = 1;
            }
        }
    } catch (const Violation& e) { std::cerr << name(e.code) << '\n'; }
    catch (const std::exception& e) { std::cerr << e.what() << '\n'; }
    return 1;
}
