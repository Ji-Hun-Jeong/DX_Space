#include "Header.hlsli"
cbuffer NormalConstant : register(b0)
{
    matrix model;
    matrix invTranspose;
    float normalSize;
    bool useNormal;
    float2 dummy;
}
cbuffer ViewProj : register(b1)
{
    matrix viewProj;
}
[maxvertexcount(2)]
void main(
	point GSInput input[1], uint primID : SV_PrimitiveID,
	inout LineStream<PSInput> outputStream
)
{
	for (uint i = 0; i < 2; i++)
	{
        PSInput output;
        float4 pos = float4(input[0].position, 1.0f);
        float3 normal = input[0].normal;
        pos.xyz += normal * i * normalSize;
        output.posWorld = pos;
        pos = mul(pos, viewProj);
        output.posProj = pos;
        
        output.normal = normal;
        output.uv = input[0].uv;
        output.uv.x = i;
        output.tangent = input[0].tangent;
        outputStream.Append(output);
    }
}