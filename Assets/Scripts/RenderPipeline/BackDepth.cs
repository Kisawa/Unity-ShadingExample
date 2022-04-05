using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class BackDepth : ScriptableRendererFeature
{
    class BackDepthPass : ScriptableRenderPass
    {
        static readonly ShaderTagId ShaderTag = new ShaderTagId("BackDepth");
        static readonly int _BackDepthTexture = Shader.PropertyToID("_BackDepthTexture");

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            RenderTextureDescriptor blitTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            cmd.GetTemporaryRT(_BackDepthTexture, blitTargetDescriptor.width, blitTargetDescriptor.height, 16, FilterMode.Bilinear, RenderTextureFormat.Depth);
            ConfigureTarget(_BackDepthTexture);
            ConfigureClear(ClearFlag.All, Color.clear);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            DrawingSettings drawing = CreateDrawingSettings(ShaderTag, ref renderingData, SortingCriteria.CommonOpaque);
            FilteringSettings filtering = new FilteringSettings(RenderQueueRange.all);
            context.DrawRenderers(renderingData.cullResults, ref drawing, ref filtering);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(_BackDepthTexture);
        }
    }

    BackDepthPass backDepthPass;

    public override void Create()
    {
        backDepthPass = new BackDepthPass();
        backDepthPass.renderPassEvent = RenderPassEvent.BeforeRenderingPrepasses;
        name = "BackDepth";
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(backDepthPass);
    }
}