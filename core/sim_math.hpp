#pragma once
#include "error.hpp"
#include <array>
#include <cmath>
#include <algorithm>
namespace astra {
struct Vec3 {
    double x{}, y{}, z{};
    bool operator==(const Vec3&) const = default;
};
inline Vec3 operator+(Vec3 a, Vec3 b) { return {a.x+b.x,a.y+b.y,a.z+b.z}; }
inline Vec3 operator-(Vec3 a, Vec3 b) { return {a.x-b.x,a.y-b.y,a.z-b.z}; }
inline Vec3 operator*(Vec3 a, double s) { return {a.x*s,a.y*s,a.z*s}; }
inline Vec3 operator/(Vec3 a, double s) { require(s != 0,Error::InvalidState); return a*(1/s); }
inline double dot(Vec3 a,Vec3 b) { return a.x*b.x+a.y*b.y+a.z*b.z; }
inline Vec3 cross(Vec3 a,Vec3 b) { return {a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x}; }
inline double length(Vec3 a) { return std::sqrt(dot(a,a)); }
inline bool finite(Vec3 a) { return std::isfinite(a.x)&&std::isfinite(a.y)&&std::isfinite(a.z); }
inline void bounded(double n,double lo,double hi) {
    require(std::isfinite(n)&&n>=lo&&n<=hi,Error::InvalidRequest);
}
using Mat3=std::array<std::array<double,3>,3>;
inline Mat3 diagonal(double x,double y,double z) { return {{{x,0,0},{0,y,0},{0,0,z}}}; }
inline Vec3 transform(const Mat3& m,Vec3 v) {
    return {dot({m[0][0],m[0][1],m[0][2]},v),dot({m[1][0],m[1][1],m[1][2]},v),dot({m[2][0],m[2][1],m[2][2]},v)};
}
inline Mat3 multiply(const Mat3& a,const Mat3& b) {
    Mat3 r{};
    for(unsigned i=0;i<3;++i) for(unsigned j=0;j<3;++j) for(unsigned k=0;k<3;++k) r[i][j]+=a[i][k]*b[k][j];
    return r;
}
inline Mat3 transpose(Mat3 m) { for(unsigned i=0;i<3;++i)for(unsigned j=i+1;j<3;++j)std::swap(m[i][j],m[j][i]);return m; }
Mat3 inverse(const Mat3&);
struct PrincipalAxes { Vec3 inertia; Mat3 rotation; };
PrincipalAxes principal_axes(const Mat3&);
}
