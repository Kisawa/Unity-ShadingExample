using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class FurryObjectRenderer : ScriptableRendererFeature
{
    public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;
    public Setting setting = new Setting();

    class FurryObjectPass : ScriptableRenderPass
    {
        static readonly string RenderTag = "FurryObjectRenderer";
        static readonly ShaderTagId ShaderTag = new ShaderTagId("FurryForward");
        static readonly int _FurryRefer = Shader.PropertyToID("_FurryRefer");
        static readonly int _FurryOffset = Shader.PropertyToID("_FurryOffset");
        static readonly int _Gravity = Shader.PropertyToID("_Gravity");
        static readonly int _GravityStrength = Shader.PropertyToID("_GravityStrength");

        Setting setting;

        public FurryObjectPass(Setting setting)
        {
            this.setting = setting;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(RenderTag);
            DrawingSettings drawing = CreateDrawingSettings(ShaderTag, ref renderingData, SortingCriteria.CommonOpaque);
            FilteringSettings filtering = new FilteringSettings(RenderQueueRange.all, setting.LayerMask);
            for (int i = 0; i < setting.PassCount; i++)
            {
                cmd.Clear();
                cmd.SetGlobalFloat(_FurryRefer, (float)i / setting.PassCount);
                cmd.SetGlobalFloat(_FurryOffset, i * setting.FurryStep);
                cmd.SetGlobalVector(_Gravity, Physics.gravity);
                cmd.SetGlobalFloat(_GravityStrength, setting.GravityStrength);
                context.ExecuteCommandBuffer(cmd);
                context.DrawRenderers(renderingData.cullResults, ref drawing, ref filtering);
            }
            CommandBufferPool.Release(cmd);
        }
    }

    FurryObjectPass furryObjectPass;

    public override void Create()
    {
        furryObjectPass = new FurryObjectPass(setting);
        furryObjectPass.renderPassEvent = Event;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(furryObjectPass);
    }

    [System.Serializable]
    public class Setting
    {
        public LayerMask LayerMask;
        [Range(1, 100)]
        public int PassCount = 1;
        [Range(.001f, .1f)]
        public float FurryStep = .005f;
        [Range(0, .1f)]
        public float GravityStrength = .05f;
    }
}