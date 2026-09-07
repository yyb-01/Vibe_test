#include "allocation_probe.hpp"
#include <cstdlib>
#include <limits>
#include <new>
#ifdef _WIN32
#include <malloc.h>
#endif

namespace {
thread_local bool probing = false;
thread_local std::size_t calls = 0, failAfter = 0;
void before_allocation() {
    if (probing && calls++ >= failAfter) throw std::bad_alloc();
}
void* allocate(std::size_t size) {
    before_allocation();
    if (void* memory = std::malloc(size ? size : 1)) return memory;
    throw std::bad_alloc();
}
void* allocate_aligned(std::size_t size, std::size_t alignment) {
    before_allocation();
    size = size ? size : 1;
#ifdef _WIN32
    void* memory = _aligned_malloc(size, alignment);
#else
    if (size > std::numeric_limits<std::size_t>::max() - (alignment - 1)) throw std::bad_alloc();
    void* memory = std::aligned_alloc(alignment, (size + alignment - 1) / alignment * alignment);
#endif
    if (memory) return memory;
    throw std::bad_alloc();
}
void release_aligned(void* memory) noexcept {
#ifdef _WIN32
    _aligned_free(memory);
#else
    std::free(memory);
#endif
}
}
namespace allocation_probe {
Scope::Scope(std::size_t limit) { calls = 0; failAfter = limit; probing = true; }
Scope::~Scope() { probing = false; }
std::size_t Scope::count() const { return calls; }
}
void* operator new(std::size_t size) { return allocate(size); }
void* operator new[](std::size_t size) { return allocate(size); }
void operator delete(void* memory) noexcept { std::free(memory); }
void operator delete[](void* memory) noexcept { std::free(memory); }
void operator delete(void* memory, std::size_t) noexcept { std::free(memory); }
void operator delete[](void* memory, std::size_t) noexcept { std::free(memory); }
void* operator new(std::size_t size, std::align_val_t alignment) {
    return allocate_aligned(size, static_cast<std::size_t>(alignment));
}
void* operator new[](std::size_t size, std::align_val_t alignment) {
    return allocate_aligned(size, static_cast<std::size_t>(alignment));
}
void operator delete(void* memory, std::align_val_t) noexcept { release_aligned(memory); }
void operator delete[](void* memory, std::align_val_t) noexcept { release_aligned(memory); }
void operator delete(void* memory, std::size_t, std::align_val_t) noexcept { release_aligned(memory); }
void operator delete[](void* memory, std::size_t, std::align_val_t) noexcept { release_aligned(memory); }
