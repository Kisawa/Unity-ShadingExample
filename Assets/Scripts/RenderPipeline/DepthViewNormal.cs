using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DepthViewNormal : ScriptableRendererFeature
{
    public ShaderCull Cull;
    public bool Set_UVToView;

    static readonly int _UVToView = Shader.PropertyToID("_UVToView");

    class DepthViewNormalPass : ScriptableRenderPass
    {
        static readonly ShaderTagId ShaderTag = new ShaderTagId("DepthViewNormal");
        static readonly int _DepthViewNormalTexture = Shader.PropertyToID("_DepthViewNormalTexture");
        static readonly int _BackDepthNormalTexture = Shader.PropertyToID("_BackDepthViewNormalTexture");
        static readonly int _DpethViewNormalCull = Shader.PropertyToID("_DpethViewNormalCull");

        ShaderCull cull;

        public DepthViewNormalPass(ShaderCull cull)
        {
            this.cull = cull;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            RenderTextureDescriptor blitTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            int nameId = cull == ShaderCull.Front ? _BackDepthNormalTexture : _DepthViewNormalTexture;
            cmd.GetTemporaryRT(nameId, blitTargetDescriptor.width, blitTargetDescriptor.height, 16, FilterMode.Bilinear, RenderTextureFormat.ARGBHalf);
            ConfigureTarget(nameId);
            ConfigureClear(ClearFlag.All, Color.white);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            Shader.SetGlobalFloat(_DpethViewNormalCull, (float)(cull == ShaderCull.Front ? CullMode.Front : CullMode.Back));
            DrawingSettings drawing = CreateDrawingSettings(ShaderTag, ref renderingData, SortingCriteria.CommonOpaque);
            FilteringSettings filtering = new FilteringSettings(RenderQueueRange.all);
            context.DrawRenderers(renderingData.cullResults, ref drawing, ref filtering);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            int nameId = cull == ShaderCull.Front ? _BackDepthNormalTexture : _DepthViewNormalTexture;
            cmd.ReleaseTemporaryRT(nameId);
        }
    }

    DepthViewNormalPass depthViewNormalPass;

    public override void Create()
    {
        depthViewNormalPass = new DepthViewNormalPass(Cull);
        depthViewNormalPass.renderPassEvent = RenderPassEvent.BeforeRenderingPrepasses;
        name = Cull == ShaderCull.Front ? "BackDepthViewNormal" : "DepthViewNormal";
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (Set_UVToView)
            ShaderSet_UVToView(renderingData.cameraData.camera);
        renderer.EnqueuePass(depthViewNormalPass);
    }

    void ShaderSet_UVToView(Camera camera)
    {
        float tanFov = Mathf.Tan(camera.fieldOfView * Mathf.Deg2Rad * 0.5f);
        Vector2 invFocalLen = new Vector2(tanFov * camera.aspect, tanFov);
        Shader.SetGlobalVector(_UVToView, invFocalLen);
    }

    public enum ShaderCull
    { 
        Back,
        Front
    }
}