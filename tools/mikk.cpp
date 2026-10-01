#include "mikktspace.h"
#include <array>
#include <cmath>
#include <cstdio>
#include <vector>
#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif
struct Data {std::vector<std::array<float,8>> input;std::vector<std::array<float,4>> output;};
static Data& data(const SMikkTSpaceContext* c){return *static_cast<Data*>(c->m_pUserData);}
static int faces(const SMikkTSpaceContext* c){return int(data(c).input.size()/3);}
static int vertices(const SMikkTSpaceContext*,int){return 3;}
static void position(const SMikkTSpaceContext* c,float* out,int f,int v){for(int i=0;i<3;++i)out[i]=data(c).input[f*3+v][i];}
static void normal(const SMikkTSpaceContext* c,float* out,int f,int v){for(int i=0;i<3;++i)out[i]=data(c).input[f*3+v][i+3];}
static void uv(const SMikkTSpaceContext* c,float* out,int f,int v){for(int i=0;i<2;++i)out[i]=data(c).input[f*3+v][i+6];}
static void tangent(const SMikkTSpaceContext* c,const float* in,float sign,int f,int v){auto& out=data(c).output[f*3+v];for(int i=0;i<3;++i)out[i]=in[i];out[3]=sign;}
int main(){
#ifdef _WIN32
    _setmode(_fileno(stdin),_O_BINARY);_setmode(_fileno(stdout),_O_BINARY);
#endif
    std::array<unsigned,2> header{};
    if(std::fread(header.data(),4,2,stdin)!=2||header[0]!=0x4b4b494d||!header[1]||header[1]>150000)return 1;
    Data d;d.input.resize(header[1]*3);d.output.resize(d.input.size());
    if(std::fread(d.input.data(),sizeof(d.input[0]),d.input.size(),stdin)!=d.input.size()||std::getc(stdin)!=EOF)return 1;
    for(auto& row:d.input)for(auto value:row)if(!std::isfinite(value))return 1;
    SMikkTSpaceInterface api{};api.m_getNumFaces=faces;api.m_getNumVerticesOfFace=vertices;
    api.m_getPosition=position;api.m_getNormal=normal;api.m_getTexCoord=uv;api.m_setTSpaceBasic=tangent;
    SMikkTSpaceContext context{&api,&d};if(!genTangSpaceDefault(&context))return 1;
    for(auto& row:d.output)for(auto value:row)if(!std::isfinite(value))return 1;
    header[0]=0x544b494d;
    if(std::fwrite(header.data(),4,2,stdout)!=2||std::fwrite(d.output.data(),sizeof(d.output[0]),d.output.size(),stdout)!=d.output.size())return 1;
    return std::fflush(stdout)?1:0;
}
