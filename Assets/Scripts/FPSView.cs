using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class FPSView : MonoBehaviour
{
    private void OnGUI()
    {
        GUI.color = Color.red;
        GUI.Label(new Rect(100, 50, 100, 30), $"FPS: {1.0f / Time.smoothDeltaTime * Time.timeScale}");
    }
}