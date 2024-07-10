#include "pch.h"
#include "ModelLoader.h"
#include <filesystem>
#include <DirectXMesh.h>
#include "Object.h"
ModelLoader ModelLoader::m_inst;
ModelLoader::ModelLoader()
{

}

void ModelLoader::Load(std::string basePath, std::string filename) {
	this->basePath = basePath;

	Assimp::Importer importer;

	const aiScene* pScene = importer.ReadFile(
		this->basePath + filename,
		aiProcess_Triangulate | aiProcess_ConvertToLeftHanded);

	if (!pScene) {
		std::cout << "Failed to read file: " << this->basePath + filename
			<< std::endl;
	}
	else {
		Matrix tr; // Initial transformation
		ProcessNode(pScene->mRootNode, pScene, tr);
	}

	// ��� ���Ͱ� ���� ��츦 ����Ͽ� �ٽ� ���
	// �� ��ġ���� �� ���ؽ��� �־�� ���� ���踦 ã�� �� ����
	/* for (auto &m : this->meshes) {

		vector<Vector3> normalsTemp(m.vertices.size(), Vector3(0.0f));
		vector<float> weightsTemp(m.vertices.size(), 0.0f);

		for (int i = 0; i < m.indices.size(); i += 3) {

			int idx0 = m.indices[i];
			int idx1 = m.indices[i + 1];
			int idx2 = m.indices[i + 2];

			auto v0 = m.vertices[idx0];
			auto v1 = m.vertices[idx1];
			auto v2 = m.vertices[idx2];

			auto faceNormal =
				(v1.position - v0.position).Cross(v2.position - v0.position);

			normalsTemp[idx0] += faceNormal;
			normalsTemp[idx1] += faceNormal;
			normalsTemp[idx2] += faceNormal;
			weightsTemp[idx0] += 1.0f;
			weightsTemp[idx1] += 1.0f;
			weightsTemp[idx2] += 1.0f;
		}

		for (int i = 0; i < m.vertices.size(); i++) {
			if (weightsTemp[i] > 0.0f) {
				m.vertices[i].normal = normalsTemp[i] / weightsTemp[i];
				m.vertices[i].normal.Normalize();
			}
		}
	}*/
}

void ModelLoader::ProcessNode(aiNode* node, const aiScene* scene, Matrix tr) {

	// std::cout << node->mName.C_Str() << " : " << node->mNumMeshes << " "
	//           << node->mNumChildren << std::endl;

	Matrix m;
	ai_real* temp = &node->mTransformation.a1;
	float* mTemp = &m._11;

	for (int t = 0; t < 16; t++) 
	{
		mTemp[t] = float(temp[t]);
	}

	m = m.Transpose() * tr;

	for (UINT i = 0; i < node->mNumMeshes; i++) 
	{
		aiMaterial* material;
		aiMesh* mesh = scene->mMeshes[node->mMeshes[i]];
		auto newMesh = this->ProcessMesh(mesh, scene, &material);

		for (auto& v : newMesh.vertices) {
			v.position = DirectX::SimpleMath::Vector3::Transform(v.position, m);
		}
		UpdateTangents(newMesh);
		resultMesh = make_shared<Object>("Character", Vector3(0.0f), Vector3(0.0f), Vector3(0.0f), Vector3(0.01f));
		resultMesh->Init(newMesh, L"Basic", L"Basic");
		string albedo =
			ReadFilename(material, aiTextureType_BASE_COLOR);
		string emissive =
			ReadFilename(material, aiTextureType_EMISSIVE);
		string height =
			ReadFilename(material, aiTextureType_HEIGHT);
		string normal =
			ReadFilename(material, aiTextureType_NORMALS);
		string metalness =
			ReadFilename(material, aiTextureType_METALNESS);
		string roughness =
			ReadFilename(material, aiTextureType_DIFFUSE_ROUGHNESS);
		string ao =
			ReadFilename(material, aiTextureType_AMBIENT_OCCLUSION);

		resultMesh->ReadImage(albedo, TEXTURE_TYPE::ALBEDO, true);
		resultMesh->ReadImage(height, TEXTURE_TYPE::HEIGHT);
		resultMesh->ReadImage(normal, TEXTURE_TYPE::NORMAL);
		resultMesh->ReadImage(metalness, TEXTURE_TYPE::METAL);
		resultMesh->ReadImage(roughness, TEXTURE_TYPE::ROUGHNESS);
		resultMesh->ReadImage(ao, TEXTURE_TYPE::AO);
		
	}

	for (UINT i = 0; i < node->mNumChildren; i++) {
		this->ProcessNode(node->mChildren[i], scene, m);
	}
}

string ModelLoader::ReadFilename(aiMaterial* material, aiTextureType type) {

	if (material->GetTextureCount(type) > 0) {
		aiString filepath;
		material->GetTexture(type, 0, &filepath);

		std::string fullPath =
			this->basePath +
			std::string(
				std::filesystem::path(filepath.C_Str()).filename().string());

		return fullPath;
	}
	else {
		return "";
	}
}

void ModelLoader::UpdateTangents(MeshData& meshData) {

	using namespace std;
	using namespace DirectX;

	// https://github.com/microsoft/DirectXMesh/wiki/ComputeTangentFrame

	vector<XMFLOAT3> positions(meshData.vertices.size());
	vector<XMFLOAT3> normals(meshData.vertices.size());
	vector<XMFLOAT2> texcoords(meshData.vertices.size());
	vector<XMFLOAT3> tangents(meshData.vertices.size());
	vector<XMFLOAT3> bitangents(meshData.vertices.size());

	for (size_t i = 0; i < meshData.vertices.size(); i++) {
		auto& v = meshData.vertices[i];
		positions[i] = v.position;
		normals[i] = v.normal;
		texcoords[i] = v.uv;
	}

	ComputeTangentFrame(meshData.indices.data(), meshData.indices.size() / 3,
		positions.data(), normals.data(), texcoords.data(),
		meshData.vertices.size(), tangents.data(),
		bitangents.data());

	for (size_t i = 0; i < meshData.vertices.size(); i++) {
		meshData.vertices[i].tangent = tangents[i];
	}

}

MeshData ModelLoader::ProcessMesh(aiMesh* mesh, const aiScene* scene, aiMaterial** aiM)
{
	// Data to fill
	std::vector<Vertex> vertices;
	std::vector<uint32_t> indices;

	// Walk through each of the mesh's vertices
	for (UINT i = 0; i < mesh->mNumVertices; i++) {
		Vertex vertex;

		vertex.position.x = mesh->mVertices[i].x;
		vertex.position.y = mesh->mVertices[i].y;
		vertex.position.z = mesh->mVertices[i].z;

		vertex.normal.x = mesh->mNormals[i].x;
		vertex.normal.y = mesh->mNormals[i].y;
		vertex.normal.z = mesh->mNormals[i].z;
		vertex.normal.Normalize();

		if (mesh->mTextureCoords[0]) {
			vertex.uv.x = (float)mesh->mTextureCoords[0][i].x;
			vertex.uv.y = (float)mesh->mTextureCoords[0][i].y;
		}

		vertices.push_back(vertex);
	}

	for (UINT i = 0; i < mesh->mNumFaces; i++) {
		aiFace face = mesh->mFaces[i];
		for (UINT j = 0; j < face.mNumIndices; j++)
			indices.push_back(face.mIndices[j]);
	}

	MeshData newMesh;
	newMesh.vertices = vertices;
	newMesh.indices = indices;

	// http://assimp.sourceforge.net/lib_html/materials.html
	if (mesh->mMaterialIndex >= 0) {
		*aiM = scene->mMaterials[mesh->mMaterialIndex];
	}

	return newMesh;
}