# Unity-URP_Example
## There are some shading and effect made with URP pipeline in this repository
****
## Realtime Refraction 
__Features:__  
* DepthViewNormal (Cull: Front   Set_UVToView: true)
* Opaque Texture

>by the mesh's thickness(back depthNormal) to calc approximate focus  
 
![image](https://user-images.githubusercontent.com/71002504/161746389-0193f14b-baa4-439e-a5e0-e78f8524783d.png)  
****
## Furry  
__Features:__  
* FurryObjectRenderer (LayerMask assign)

![image](https://user-images.githubusercontent.com/71002504/161749112-e8899ceb-7579-4cd1-9f5c-860e669e47c6.png)  
![image](https://user-images.githubusercontent.com/71002504/161762997-d109b4bb-27b9-4b4f-8bde-06a312f994d5.png)  
****
## GPU Instancing Grass（10W grass in this demo）  
>No culling (TODO: cull by compute shader or quadtree)  

![image](https://user-images.githubusercontent.com/71002504/161763346-2fca316b-3a83-410e-ba36-ccf924ff6e55.png)  
****
## Screen effects
* Ground Truth Ambient Occlusion:

![image](https://user-images.githubusercontent.com/71002504/161788634-a8133e81-e844-401c-9286-9e7b55a7329a.png)  
![image](https://user-images.githubusercontent.com/71002504/161788883-9d05c1de-5ab9-4e4a-a1f4-2a08a50ddae9.png)  
* Temporal Anti-Aliasing:

![image](https://user-images.githubusercontent.com/71002504/161789750-a817ee84-571e-49bc-b490-1c66d40b2788.png)  
![image](https://user-images.githubusercontent.com/71002504/161789803-f8ef07b1-cac6-4f6a-9e05-cb1335263da2.png)  
