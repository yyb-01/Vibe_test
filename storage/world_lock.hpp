#pragma once
#include "error.hpp"
#include <filesystem>
#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#else
#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>
#endif

namespace astra {
inline std::filesystem::path world_path(const std::filesystem::path& path) {
    require(!path.empty() && path.has_filename(), Error::InvalidState);
    return std::filesystem::weakly_canonical(std::filesystem::absolute(path));
}
// Keep the sidecar: deleting it could let another process lock a different file.
class WorldLock {
#ifdef _WIN32
    HANDLE handle_{INVALID_HANDLE_VALUE};
#else
    int handle_{-1};
#endif
public:
    explicit WorldLock(std::filesystem::path path) {
        path += ".lock";
#ifdef _WIN32
        handle_ = CreateFileW(path.c_str(), GENERIC_READ | GENERIC_WRITE, 0, nullptr,
                              OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (handle_ == INVALID_HANDLE_VALUE)
            throw Violation{GetLastError() == ERROR_SHARING_VIOLATION ? Error::Busy : Error::StorageUnavailable};
#else
        handle_ = open(path.c_str(), O_CREAT | O_RDWR | O_CLOEXEC, 0600);
        require(handle_ >= 0, Error::StorageUnavailable);
        if (flock(handle_, LOCK_EX | LOCK_NB) != 0) {
            close(handle_); throw Violation{Error::Busy};
        }
#endif
    }
    ~WorldLock() {
#ifdef _WIN32
        CloseHandle(handle_);
#else
        close(handle_);
#endif
    }
    WorldLock(const WorldLock&) = delete;
    WorldLock& operator=(const WorldLock&) = delete;
};
}
