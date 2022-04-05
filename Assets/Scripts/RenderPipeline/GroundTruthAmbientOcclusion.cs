using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class GroundTruthAmbientOcclusion : ScriptableRendererFeature
{
    public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;

    public GTAOSetting Setting = new GTAOSetting();

    [System.Serializable]
    public class GTAOSetting
    {
        public ViewType ViewType = ViewType.Combine;
        [Range(3, 12)]
        public int SampleDirectionCount = 3;
        [Range(.1f, 5)]
        public float SampleRadius = 1;
        [Range(3, 32)]
        public int SampleStep = 12;
        [Range(.1f, 10)]
        public float AOPower = 2;
        [Range(0, 1)]
        public float AOThickness = 1;
        [Range(1, 5)]
        public float AOCompactness = 2;
        public bool MultiBounce = true;

        [Space(10)]
        [Range(0, 5)]
        public int BlurIterations = 3;
        [Range(.1f, 5)]
        public float BlurSpread = 1.6f;
        [Range(.001f, 5)]
        public float BlurThreshold = .1f;
    }

    public enum ViewType { Origin, AO, Combine }

    class GTAORenderPass : ScriptableRenderPass
    {
        static readonly string RenderTag = "GTAO";
        static readonly int _TempRT = Shader.PropertyToID("_TempRT");
        static readonly int _AOMap = Shader.PropertyToID("_AOMap");

        static int _TexelSize = Shader.PropertyToID("_TexelSize");
        static int _UVToView = Shader.PropertyToID("_UVToView");
        static int _ProjScale = Shader.PropertyToID("_ProjScale");
        static int _SampleDirectionCount = Shader.PropertyToID("_SampleDirectionCount");
        static int _SampleRadius = Shader.PropertyToID("_SampleRadius");
        static int _SampleStep = Shader.PropertyToID("_SampleStep");
        static int _AOPower = Shader.PropertyToID("_AOPower");
        static int _AOThickness = Shader.PropertyToID("_AOThickness");
        static int _AOCompactness = Shader.PropertyToID("_AOCompactness");
        static int _MultiBounce = Shader.PropertyToID("_MultiBounce");

        static int _BlurSpread = Shader.PropertyToID("_BlurSpread");
        static int _BlurThreshold = Shader.PropertyToID("_BlurThreshold");

        GTAOSetting setting;
        Material mat;
        int temp_id = -1;
        RenderTargetIdentifier temp;
        int aoMap_id = -1;
        RenderTargetIdentifier aoMap;

        public GTAORenderPass(GTAOSetting setting)
        {
            this.setting = setting;
            Shader shader = Shader.Find("PostProcessing/GTAO");
            if (shader == null)
            {
                Debug.LogError("GTAORenderPass: shader not found.");
                return;
            }
            mat = CoreUtils.CreateEngineMaterial(shader);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            if (mat == null)
            {
                temp_id = -1;
                temp_id = -1;
                return;
            }
            RenderTextureDescriptor blitTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            blitTargetDescriptor.depthBufferBits = 0;
            int width = blitTargetDescriptor.width;
            int height = blitTargetDescriptor.height;
            blitTargetDescriptor.bindMS = false;
            temp_id = _TempRT;
            cmd.GetTemporaryRT(temp_id, blitTargetDescriptor, FilterMode.Point);
            temp = new RenderTargetIdentifier(temp_id);

            aoMap_id = _AOMap;
            cmd.GetTemporaryRT(aoMap_id, width, height, 0, FilterMode.Point, RenderTextureFormat.RG32);
            aoMap = new RenderTargetIdentifier(aoMap_id);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (mat == null)
            {
                Debug.LogError("TAARenderPass: material not created.");
                return;
            }
            RenderTargetIdentifier source = renderingData.cameraData.renderer.cameraColorTarget;
            RenderTextureDescriptor blitTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            CommandBuffer cmd = CommandBufferPool.Get(RenderTag);
            Camera cam = renderingData.cameraData.camera;
            float tanFov = Mathf.Tan(cam.fieldOfView * Mathf.Deg2Rad * 0.5f);
            Vector2 invFocalLen = new Vector2(tanFov * cam.aspect, tanFov);
            mat.SetVector(_UVToView, invFocalLen);
            float projScale = cam.pixelHeight / 2 / tanFov;
            mat.SetFloat(_ProjScale, projScale);
            mat.SetInt(_SampleDirectionCount, setting.SampleDirectionCount);
            mat.SetFloat(_SampleRadius, setting.SampleRadius);
            mat.SetInt(_SampleStep, setting.SampleStep);
            mat.SetFloat(_AOPower, setting.AOPower);
            mat.SetFloat(_AOThickness, setting.AOThickness);
            mat.SetFloat(_AOCompactness, setting.AOCompactness);
            mat.SetFloat(_MultiBounce, setting.MultiBounce ? 1 : 0);
            int width = blitTargetDescriptor.width;
            int height = blitTargetDescriptor.height;
            mat.SetVector(_TexelSize, new Vector4(1f / width, 1f / height, width, height));
            mat.SetFloat(_BlurSpread, setting.BlurSpread);
            mat.SetFloat(_BlurThreshold, setting.BlurThreshold);
            mat.SetInt("_ViewType", (int)setting.ViewType);

            Blit(cmd, source, aoMap, mat, 0);
            for (int i = 0; i < setting.BlurIterations; i++)
            {
                Blit(cmd, aoMap, temp, mat, 1);
                Blit(cmd, temp, aoMap);
            }
            Blit(cmd, source, temp, mat, 2);
            Blit(cmd, temp, source);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            if (temp_id != -1)
                cmd.ReleaseTemporaryRT(temp_id);
            if (temp_id != -1)
                cmd.ReleaseTemporaryRT(temp_id);
        }
    }

    GTAORenderPass gtaoPass;

    public override void Create()
    {
        gtaoPass = new GTAORenderPass(Setting);
        gtaoPass.renderPassEvent = Event;
        name = "GTAO";
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(gtaoPass);
    }
}


