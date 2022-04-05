using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class TemporalAntiAliasing : ScriptableRendererFeature
{
    public RenderPassEvent Event = RenderPassEvent.BeforeRenderingPostProcessing;

    public TAASetting Setting = new TAASetting();

    const int _JitterCount = 8;
    int jitterIndex;

    [System.Serializable]
    public class TAASetting
    {
        [Range(0, 100)]
        public float JitterSpread = 0.75f;
        [Range(0, 1)]
        public float BlendMin = .75f;
        [Range(0, 1)]
        public float BlendMax = .95f;

        public Matrix4x4 jitterProj { get; set; }
        public Vector4 jitterTexelSize { get; set; }
    }

    class JitterPass : ScriptableRenderPass
    {
        static readonly string RenderTag = "Jitter";

        TAASetting setting;

        public JitterPass(TAASetting setting)
        {
            this.setting = setting;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(RenderTag);
            cmd.SetViewProjectionMatrices(renderingData.cameraData.camera.worldToCameraMatrix, setting.jitterProj);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }

    class TAARenderPass : ScriptableRenderPass
    {
        static readonly string RenderTag = "TAA";
        static readonly int _PrevRT = Shader.PropertyToID("_PrevTex");
        static readonly int _TempRT = Shader.PropertyToID("_TempRT");
        static readonly int _JitterTexelOffset = Shader.PropertyToID("_JitterTexelOffset");
        static readonly int _Blend = Shader.PropertyToID("_Blend");

        TAASetting setting;
        Material mat;
        int temp_id = -1;
        int prev_id = -1;
        RenderTargetIdentifier prev;
        RenderTargetIdentifier temp;

        public TAARenderPass(TAASetting setting)
        {
            this.setting = setting;
            Shader shader = Shader.Find("PostProcessing/TAA");
            if (shader == null)
            {
                Debug.LogError("TAARenderPass: shader not found.");
                return;
            }
            mat = CoreUtils.CreateEngineMaterial(shader);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            if (mat == null)
            {
                temp_id = -1;
                prev_id = -1;
                return;
            }
            RenderTextureDescriptor blitTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            blitTargetDescriptor.depthBufferBits = 0;
            temp_id = _TempRT;
            cmd.GetTemporaryRT(temp_id, blitTargetDescriptor);
            temp = new RenderTargetIdentifier(temp_id);
            prev_id = _PrevRT;
            cmd.GetTemporaryRT(prev_id, blitTargetDescriptor);
            prev = new RenderTargetIdentifier(prev_id);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (mat == null)
            {
                Debug.LogError("TAARenderPass: material not created.");
                return;
            }
            RenderTargetIdentifier source = renderingData.cameraData.renderer.cameraColorTarget;
            CommandBuffer cmd = CommandBufferPool.Get(RenderTag);
            mat.SetVector(_JitterTexelOffset, setting.jitterTexelSize);
            mat.SetVector(_Blend, new Vector2(setting.BlendMin, setting.BlendMax));
            Blit(cmd, source, temp, mat, 0);
            Blit(cmd, temp, prev);
            Blit(cmd, temp, source);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            if (temp_id != -1)
                cmd.ReleaseTemporaryRT(temp_id);
            if (prev_id != -1)
                cmd.ReleaseTemporaryRT(prev_id);
        }
    }

    JitterPass jitterPass;
    TAARenderPass taaPass;

    public override void Create()
    {
        jitterPass = new JitterPass(Setting);
        jitterPass.renderPassEvent = RenderPassEvent.BeforeRenderingPrepasses;
        taaPass = new TAARenderPass(Setting);
        taaPass.renderPassEvent = Event;
        name = "TAA";
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (renderingData.cameraData.isSceneViewCamera)
            return;
        Vector2 offset = new Vector2(HaltonSeq(2, jitterIndex + 1), HaltonSeq(3, jitterIndex + 1));
        offset = (offset - Vector2.one * 0.5f) * Setting.JitterSpread;
        jitterIndex++;
        jitterIndex = jitterIndex >= _JitterCount ? 0 : jitterIndex;
        Matrix4x4 proj = CalcProjectionMatrix(renderingData.cameraData.camera, offset);
        Vector4 jitterTexelSize = Setting.jitterTexelSize;
        jitterTexelSize.z = jitterTexelSize.x;
        jitterTexelSize.w = jitterTexelSize.y;
        jitterTexelSize.x = offset.x;
        jitterTexelSize.y = offset.y;
        Setting.jitterTexelSize = jitterTexelSize;
        Setting.jitterProj = proj;
        renderer.EnqueuePass(jitterPass);
        renderer.EnqueuePass(taaPass);
    }

    static float HaltonSeq(int refer, int index = 1/* NOT! zero-based */)
    {
        float result = 0;
        float fraction = 1;
        int i = index;
        while (i > 0)
        {
            fraction /= refer;
            result += fraction * (i % refer);
            i = (int)Mathf.Floor(i / (float)refer);
        }
        return result;
    }

    static Matrix4x4 CalcProjectionMatrix(Camera camera, Vector2 texelOffset)
    {
        Matrix4x4 projectionMatrix = new Matrix4x4();
        texelOffset.x /= .5f * camera.pixelWidth;
        texelOffset.y /= .5f * camera.pixelHeight;
        if (camera.orthographic)
        {
            float vertical = camera.orthographicSize;
            float horizontal = vertical * camera.aspect;
            texelOffset.x *= horizontal;
            texelOffset.y *= vertical;
            float right = texelOffset.x + horizontal;
            float left = texelOffset.x - horizontal;
            float top = texelOffset.y + vertical;
            float bottom = texelOffset.y - vertical;

            projectionMatrix.m00 = 2 / (right - left);
            projectionMatrix.m03 = -(right + left) / (right - left);
            projectionMatrix.m11 = 2 / (top - bottom);
            projectionMatrix.m13 = -(top + bottom) / (top - bottom);
            projectionMatrix.m22 = -2 / (camera.farClipPlane - camera.nearClipPlane);
            projectionMatrix.m23 = -(camera.farClipPlane + camera.nearClipPlane) / (camera.farClipPlane - camera.nearClipPlane);
            projectionMatrix.m33 = 1;
        }
        else
        {
            float thfov = Mathf.Tan(camera.fieldOfView * Mathf.Deg2Rad / 2);
            float frustumDepth = camera.farClipPlane - camera.nearClipPlane;
            float oneOverDepth = 1 / frustumDepth;

            projectionMatrix.m00 = 1 / thfov / camera.aspect;
            projectionMatrix.m11 = 1 / thfov;
            projectionMatrix.m22 = -(camera.farClipPlane + camera.nearClipPlane) * oneOverDepth;
            projectionMatrix.m23 = -2 * camera.nearClipPlane * camera.farClipPlane * oneOverDepth;
            projectionMatrix.m32 = -1;
            projectionMatrix.m02 = texelOffset.x;
            projectionMatrix.m12 = texelOffset.y;
        }
        return projectionMatrix;
    }
}