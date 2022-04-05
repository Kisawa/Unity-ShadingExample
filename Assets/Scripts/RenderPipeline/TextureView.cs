using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class TextureView : ScriptableRendererFeature
{
    public string RenderTextureName;
    public TextureType Type;

    class TextureViewPass : ScriptableRenderPass
    {
        static readonly string RenderTag = "TextureView";
        static readonly string DepthTextureKeyword = "_DEPTHTEXTURE";
        static readonly string DepthNormalTextureKeyword = "_DEPTHNORMALTEXTURE";

        Material mat;
        TextureType type;
        int viewTextureId = -1;
        RenderTargetIdentifier viewTexture;

        public TextureViewPass(string name, TextureType type)
        {
            Shader shader = Shader.Find("PostProcessing/TextureView");
            if (shader == null)
            {
                Debug.LogError("TextureViewPass: shader not found.");
                return;
            }
            mat = CoreUtils.CreateEngineMaterial(shader);
            this.type = type;
            if (string.IsNullOrEmpty(name))
                return;
            viewTextureId = Shader.PropertyToID(name);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            if (mat == null || viewTextureId == -1)
                return;
            viewTexture = new RenderTargetIdentifier(viewTextureId);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (viewTextureId == -1)
                return;
            if (mat == null)
            {
                Debug.LogError("TextureViewPass: material not created.");
                return;
            }
            RenderTargetIdentifier source = renderingData.cameraData.renderer.cameraColorTarget;
            CommandBuffer cmd = CommandBufferPool.Get(RenderTag);
            CoreUtils.SetKeyword(cmd, DepthTextureKeyword, type == TextureType.DepthTexture);
            CoreUtils.SetKeyword(cmd, DepthNormalTextureKeyword, type == TextureType.DepthNormalTexture);
            Blit(cmd, viewTexture, source, mat, 0);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }

    TextureViewPass viewPass;

    public override void Create()
    {
        viewPass = new TextureViewPass(RenderTextureName, Type);
        viewPass.renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (renderingData.cameraData.isSceneViewCamera)
            return;
        renderer.EnqueuePass(viewPass);
    }

    public enum TextureType
    { 
        None,
        DepthTexture,
        DepthNormalTexture
    }
}
