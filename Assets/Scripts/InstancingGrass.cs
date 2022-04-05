using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class InstancingGrass : MonoBehaviour
{
    static int _InstancingPosBuffer = Shader.PropertyToID("_InstancingPosBuffer");

    public Material Mat;
    [Range(1, 1000000)]
    public int InstancingCount = 100000;

    Bounds bounds;
    Mesh mesh;
    List<Vector4> instancingPos;
    ComputeBuffer instancingPosBuffer;
    ComputeBuffer argsBuffer;

    private void OnEnable()
    {
        if (mesh == null)
        {
            mesh = new Mesh();
            Vector3[] vertices = new Vector3[3];
            vertices[0] = new Vector3(-.05f, 0);
            vertices[1] = new Vector3(.05f, 0);
            vertices[2] = new Vector3(0, 1);
            int[] triangles = new int[3] { 2, 1, 0 };
            mesh.SetVertices(vertices);
            mesh.SetTriangles(triangles, 0);
        }
        bounds = GetComponent<MeshRenderer>().bounds;
    }

    private void OnDisable()
    {
        if (instancingPosBuffer != null)
            instancingPosBuffer.Release();
        instancingPosBuffer = null;
        if (argsBuffer != null)
            argsBuffer.Release();
        argsBuffer = null;
    }

    private void LateUpdate()
    {
        if (mesh == null || Mat == null)
            return;
        UpdateInstancing();
        Graphics.DrawMeshInstancedIndirect(mesh, 0, Mat, bounds, argsBuffer);
    }

    void UpdateInstancing()
    {
        if (instancingPos == null || instancingPos.Count != InstancingCount)
        {
            Random.InitState(0);
            instancingPos = new List<Vector4>(InstancingCount);
            Vector3 origin = transform.position;
            for (int i = 0; i < InstancingCount; i++)
            {
                float angle = Random.Range(-Mathf.PI, Mathf.PI);
                float distance = Random.Range(0, 5f);
                float size = Random.Range(.1f, .5f);
                Vector4 pos = new Vector3(Mathf.Sin(angle) * distance, 0, Mathf.Cos(angle) * distance) + origin;
                pos.w = size;
                instancingPos.Add(pos);
            }
            if (instancingPosBuffer != null)
                instancingPosBuffer.Release();
            instancingPosBuffer = null;
            if (argsBuffer != null)
                argsBuffer.Release();
            argsBuffer = null;
            Debug.Log("Update instancing count");
        }
        if (instancingPosBuffer == null)
        {
            instancingPosBuffer = new ComputeBuffer(InstancingCount, sizeof(float) * 4);
            instancingPosBuffer.SetData(instancingPos);
            Mat.SetBuffer(_InstancingPosBuffer, instancingPosBuffer);
        }
        if (argsBuffer == null)
        {
            argsBuffer = new ComputeBuffer(1, sizeof(uint) * 5, ComputeBufferType.IndirectArguments);
            uint[] args = new uint[5] { 0, 0, 0, 0, 0 };
            args[0] = mesh.GetIndexCount(0);
            args[1] = (uint)InstancingCount;
            args[2] = mesh.GetIndexStart(0);
            args[3] = mesh.GetBaseVertex(0);
            argsBuffer.SetData(args);
        }
    }
}