using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class StencilExpressionRenderer : ScriptableRendererFeature
{
    class StencilExpressionPass : ScriptableRenderPass
    {
        static readonly ShaderTagId ShaderTag = new ShaderTagId("StencilExpression");

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            DrawingSettings drawing = CreateDrawingSettings(ShaderTag, ref renderingData, SortingCriteria.CommonOpaque);
            FilteringSettings filtering = new FilteringSettings(RenderQueueRange.all);
            context.DrawRenderers(renderingData.cullResults, ref drawing, ref filtering);
        }
    }

    StencilExpressionPass stencilExpressionPass;

    public override void Create()
    {
        stencilExpressionPass = new StencilExpressionPass();
        stencilExpressionPass.renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
        name = "StencilExpression";
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(stencilExpressionPass);
    }
}