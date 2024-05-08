#pragma once
#include "Mesh.h"
class DirArrow :
    public Mesh
{
public:
    explicit DirArrow(const Vector3& translation, const Vector3& rotation1, const Vector3& rotation2, const Vector3& scale, D3D11_PRIMITIVE_TOPOLOGY topology = D3D11_PRIMITIVE_TOPOLOGY_POINTLIST);
public:
    virtual void Init(const string& name, const MeshData& meshData, const wstring& vertexShaderPrefix, const wstring& pixelShaderPrefix) override;
    virtual void Update(float dt) override;
    virtual void UpdateVertexConstantData(float dt) override;
    virtual void ReadyToRender(ID3D11DeviceContext* context) override;
private:
    DirArrowConstantData m_dirArrowConstantData;
};
