using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class CharacterRenderer : MonoBehaviour
{
    static int _BoundCenterPosWS = Shader.PropertyToID("_BoundCenterPosWS");
    static int _PerspectiveCorrectUsage = Shader.PropertyToID("_PerspectiveCorrectUsage");

    [Range(0, 1)]
    public float PerspectiveCorrectUsage;

    Transform trans;
    Renderer[] renderers;

    private void Awake()
    {
        trans = transform;
        renderers = GetComponentsInChildren<Renderer>();
    }

    private void Update()
    {
        for (int i = 0; i < renderers.Length; i++)
        {
            Renderer renderer = renderers[i];
            for (int j = 0; j < renderer.sharedMaterials.Length; j++)
            {
                Material mat = renderer.sharedMaterials[j];
                if (mat == null)
                    continue;
                mat.SetVector(_BoundCenterPosWS, trans.position);
                mat.SetFloat(_PerspectiveCorrectUsage, PerspectiveCorrectUsage);
            }
        }
    }
}