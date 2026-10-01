#include "host.hpp"
#include <iostream>
int wmain(int argc,wchar_t** argv) {
    try {
        if(argc!=3||std::wstring(argv[1])!=L"--save")throw std::runtime_error("usage: astra-game --save <path>");
        astra::native::Host host{std::filesystem::path(argv[2])};
        std::cout<<"{\"ready\":true,\"protocol\":1}"<<std::endl;
        std::string line;
        while(std::getline(std::cin,line)) {
            if(line=="quit"){if(host.close()){std::cout<<"{\"closed\":true}"<<std::endl;return 0;}std::cout<<"{\"closed\":false}"<<std::endl;continue;}
            std::cout<<host.execute(line)<<std::endl;
        }
        return host.close()?0:1;
    } catch(const astra::Violation& e){std::cerr<<astra::name(e.code)<<std::endl;return 1;}
    catch(const std::exception& e){std::cerr<<e.what()<<std::endl;return 1;}
}
