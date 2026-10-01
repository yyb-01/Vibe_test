#include "sim_math.hpp"
namespace astra {
Mat3 inverse(const Mat3& m) {
    Mat3 r{};
    for(unsigned i=0;i<3;++i)for(unsigned j=0;j<3;++j)
        r[j][i]=m[(i+1)%3][(j+1)%3]*m[(i+2)%3][(j+2)%3]-m[(i+1)%3][(j+2)%3]*m[(i+2)%3][(j+1)%3];
    auto d=m[0][0]*r[0][0]+m[0][1]*r[1][0]+m[0][2]*r[2][0];
    require(std::isfinite(d)&&d>1e-12,Error::InvalidState);
    for(auto& row:r)for(auto& v:row)v/=d;
    return r;
}
PrincipalAxes principal_axes(const Mat3& input) {
    auto m=input; auto axes=diagonal(1,1,1);
    double scale=0;
    for(unsigned i=0;i<3;++i)for(unsigned j=0;j<3;++j) {
        require(std::isfinite(m[i][j]),Error::InvalidState);scale=std::max(scale,std::abs(m[i][j]));
    }
    require(scale>0,Error::InvalidState);
    for(unsigned i=0;i<3;++i)for(unsigned j=0;j<3;++j)
        require(std::abs(m[i][j]-m[j][i])<=scale*1e-6,Error::InvalidState);
    for(unsigned n=0;n<32;++n) {
        unsigned p=0,q=1;
        for(unsigned i=0;i<3;++i)for(unsigned j=i+1;j<3;++j)
            if(std::abs(m[i][j])>std::abs(m[p][q])){p=i;q=j;}
        if(std::abs(m[p][q])<=scale*1e-12)break;
        double a=.5*std::atan2(2*m[p][q],m[q][q]-m[p][p]);
        auto r=diagonal(1,1,1);r[p][p]=r[q][q]=std::cos(a);r[p][q]=std::sin(a);r[q][p]=-std::sin(a);
        m=multiply(transpose(r),multiply(m,r));axes=multiply(axes,r);
    }
    auto lo=std::min({m[0][0],m[1][1],m[2][2]});
    auto hi=std::max({m[0][0],m[1][1],m[2][2]});
    require(lo>0&&hi/lo<1e8,Error::InvalidState);
    return {{m[0][0],m[1][1],m[2][2]},axes};
}
}
