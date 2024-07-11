#include "Header.hlsli"
TextureCube g_specularTexture : register(t0);
TextureCube g_irradianceTexture : register(t1);
Texture2D g_lutTexture : register(t2);
Texture2D g_albedoTexture : register(t3);
Texture2D g_normalTexture : register(t4);
Texture2D g_aoTexture : register(t5);
Texture2D g_metallicTexture : register(t6);
Texture2D g_roughnessTexture : register(t7);

SamplerState g_sampler : register(s0);
SamplerState g_clampSampler : register(s1);
static const float pi = 3.141592f;
cbuffer PixelConstant : register(b0)
{
    float3 eyePos;
    int isLight;
    Light light;
    Material mat;
    Bloom bloom;
    Rim rim;
    
    int useAlbedo;
    int useNormal;
    int useAO;
    int useRoughness;
    
    int useMetallic;
    float exposure;
    float gamma;
    float Metallic;
};

float CalcAttenuation(float dist)
{
    return saturate((light.fallOfEnd - dist) / (light.fallOfEnd - light.fallOfStart));
}

float3 GetNormal(PSInput input)
{
    float3 normal = g_normalTexture.Sample(g_sampler, input.uv).xyz;
    normal = 2.0f * normal - 1.0f;
    float3 N = input.normal;
    float3 T = normalize(input.tangent - dot(input.tangent, N) * N);
    float3 B = cross(N, T);
    float3x3 TBN = float3x3(T, B, N);
    normal = normalize(mul(normal, TBN));
    return normal;
}

// �������� ���°����� ���� ���� ���Ⱑ ���ϴ°�
float3 SpecularF(float3 F0, float vdoth)
{
    return F0 + (1.0 - F0) * pow(1.0 - vdoth, 5.0);
}

float3 GetDiffuseByIBL(float3 albedo, float3 normal, float3 F)
{
    // normal�������� �ѹ��� ���ø� ���� ��� �� ������ ���� �� �ִ� ���� ���� ����س��� ����
    // irradiance map
    float3 diffuseByIBL = g_irradianceTexture.Sample(g_sampler, normal).rgb;
    return F * diffuseByIBL * albedo;
}

float3 GetSpecularByIBL(float3 albedo, float3 normal, float3 v, float3 F, float roughness)
{
    float3 reflectDir = reflect(-v, normal);
    // IBL�� ���� specular brdf�� ���ϱ� ���� �Ʒ��� �� (F0 ~ + ~)�� �ʿ��ѵ� �� ���� ~�κ���
    // �̸� Look Up Table�� ����� �� ���̴�.
    // �Ʒ� ���� evBRDF.r�� evBRDF.g
    float3 evBRDF = g_lutTexture.Sample(g_clampSampler, float2(dot(v, normal), 1 - roughness));
    
    // specular�� specular�ʿ��� �����ݻ�������� �ѹ��� ���ø� �ϸ�ȴ�. ���ݻ��̱� ������
    float3 specularByIBL = g_specularTexture.SampleLevel(g_sampler, reflectDir, 5.0f * roughness);
    return specularByIBL * (F * evBRDF.r + evBRDF.g);
}

// �ֺ����� ���ϴ� ��
// �ֺ����� ���� ���� �� �ȼ��� ���ݻ�, ���ݻ�Ǿ� ������ ���� ���� ���
float3 AmbientLighting(float3 albedo, float3 ao, float3 normal, float3 v
                     , float3 h, float metallic, float roughness)
{
    float3 F0 = 0.04f;
    float3 F = lerp(F0, albedo, metallic);
    float3 diffuse = GetDiffuseByIBL(albedo, normal, 1.0f - F); // �갡 �ٸ������� ���� ���ݻ�
    float3 specular = GetSpecularByIBL(albedo, normal, v, F, roughness); // ��� �ٸ������� ���� ���ݻ�
    return (diffuse + specular) * ao ; // ���������� �� �ȼ��� ������ �ֺ��� ���� ao�� ���⼭�� ���ϱ�
}

// Normal Distribution, �츮�� ���� ������ �̼�ǥ���� �븻�� ǥ���� ���� ����ŧ������ ���̶���Ʈ�� ����
float SpecularD(float ndoth,float roughness)
{
    float minRoughness = max(roughness, 1e-5);
    float alpha = minRoughness * minRoughness;
    float alpha2 = alpha * alpha;
    float denom = ndoth * ndoth * (alpha2 - 1.0) + 1.0;
    return alpha2 / (pi * denom * denom);
}

float G1(float ndotx, float roughness)
{
    float k = (roughness + 1.0) * (roughness + 1.0) / 8.0;
    return ndotx / (ndotx * (1.0 - k) + k);
}

// Geometry Funciton, �̼�ǥ�鿡�� �ݻ�� ���� �����ų� ���� �̼�ǥ�鿡 ���� �������� ��Ȳ,
// ���������� ���� ǥ���� ������������ �����Ѵ�.
float SpecularG(float ndotl, float ndotv, float roughness)
{
    return G1(ndotl, roughness) * G1(ndotv, roughness);
}

// ���� �������� ��ü�� �¾� �ݻ�Ǵ� ���� ���� ���
// �̰��� Shading Model������ PBR ���� Image Based Lighting�� �������� ������ �� �ִ� ��
float3 DirectLight(float3 albedo, float3 normal, float3 l, float3 v, float3 h, float roughness, float metallic)
{
    float ndotl = max(dot(normal, l), 0.0f);
    float ndoth = max(dot(normal, h), 0.0f);
    float ndotv = max(dot(normal, v), 0.0f);
    float vdoth = max(dot(v, h), 0.0f);
    
    float3 F0 = 0.04f;
    // F0�� �ݻ���.
    // ����� �����ϸ� albedo���� ������ ���̰� �ݻ縦 ���� �ϸ� albedo���� �Ǿ�������̴�.
    // �װ��� metallic�� ���� �����Ǵ°��̰�
    // metallic�� 1�̵Ǿ������ �ƿ� �ݻ����� albedo�� �Ǿ������ ��
    // metallic�� �ö� ���� ���� ��ο����� ������ albedo�� 0�ΰ���̴�.
    F0 = lerp(F0, albedo, metallic);
    float3 F = SpecularF(F0, vdoth);
    float D = SpecularD(ndoth, roughness);
    float G = SpecularG(ndotl, ndotv, roughness);
    // float3 kd = lerp(1.0f - F, 0.0f, metallic);
    
    // ���� ���⸦ ���ݻ�� ���ݻ翡 ������ �ִ� ��
    // diffuse���� 1-F, specular���� F
    float3 diffuse = ((1.0f - F) * albedo) / pi;
    float3 specular = (F * D * G) / max(1e-5, 4.0f * ndotl * ndotv);
    float distance = length(l);
    float3 lightStrength = light.lightStrength * CalcAttenuation(distance);

    return (diffuse + specular) * lightStrength;
}

float4 main(PSInput input) : SV_TARGET
{    
    if(isLight)
        return float4(1.0f, 1.0f, 0.0f, 1.0f);
    float3 albedo = useAlbedo ? g_albedoTexture.SampleLevel(g_sampler, input.uv, 0) : 1.0f;
    float3 normal = useNormal ? GetNormal(input) : input.normal;
    float3 ao = useAO ? g_aoTexture.SampleLevel(g_sampler, input.uv, 0) : 1.0f;
    float metallic = useMetallic ? g_metallicTexture.Sample(g_sampler, input.uv).r : Metallic;
    float roughness = useRoughness ? g_roughnessTexture.Sample(g_sampler, input.uv).r : 0.1f;
    
    float3 l = normalize(light.lightPos - input.posWorld.xyz);
    float3 v = normalize(eyePos - input.posWorld.xyz);
    float3 h = normalize(l + v);
    float ndotl = max(0.0f, dot(l, normal));
    
    float3 ambientLight = AmbientLighting(albedo, ao, normal, v, h, metallic, roughness);
    float3 directLight = DirectLight(albedo, normal, l, v, h, roughness, metallic) * ndotl * light.lightStrength;
    float3 color = ambientLight + directLight;
    
    return float4(color, 1.0f);
}