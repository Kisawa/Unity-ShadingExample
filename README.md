# URP_Example
## Toon Shading  
Supports：  
* Light (Directional, Point, Spot, Area)
* Light Intensity, Indirect Multipiler
* Environment Lighting (Skybox, Gradient, Color)
* Light Probes

Features:  
* RenderObjects (LightMode Tags: "Outline")
* StencilExpressionRenderer

![微信图片_20220405172953](https://user-images.githubusercontent.com/71002504/161746235-2fff49bb-80e7-4857-bfec-94a28520b0e4.png)  
Red, Green and Blue lights
![image](https://user-images.githubusercontent.com/71002504/161773804-9387bbba-42eb-406e-925f-aae5153f1480.png)  
****
## Realtime Refraction 
Features:  
* DepthViewNormal (Cull: Front   Set_UVToView: true)
* Opaque Texture

by the mesh's thickness(back depthNormal) to calc approximate focus  
![image](https://user-images.githubusercontent.com/71002504/161769449-3c069b33-10cc-4f0e-9651-ce8109a8b369.png)  
![微信图片_20220405175256](https://user-images.githubusercontent.com/71002504/161746389-0193f14b-baa4-439e-a5e0-e78f8524783d.png)  
****
## Furry  
Features:  
* FurryObjectRenderer (LayerMask assign)
![微信图片_20220405174003](https://user-images.githubusercontent.com/71002504/161749112-e8899ceb-7579-4cd1-9f5c-860e669e47c6.png)  
![微信图片_20220405174828](https://user-images.githubusercontent.com/71002504/161762997-d109b4bb-27b9-4b4f-8bde-06a312f994d5.png)  
****
## GPU Instancing Grass（10W grass in this demo）  
No culling (TODO: cull by compute shader or quadtree)  
![image](https://user-images.githubusercontent.com/71002504/161763346-2fca316b-3a83-410e-ba36-ccf924ff6e55.png)  
