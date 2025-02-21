# Reshade-shader-practice
A small project to practice making post processing shader

Language: ReShade FX shading language, a shading language that is heavily based on the DX9-style HLSL syntax, with a few extensions. 

Current shader:
 - MyPixelFX.fx: a pixelate shader. Makes the game looks more retro.
 - KuwaharaFilter.fx: a Kuwahara Filter shader. Makes the game looks like oil painting, works extremely well together with pixelate shader.

## Original Image (Taken from Death Stranding by Kojima Productions)
![Original Image (Taken from Death Stranding by Kojima Productions)](https://github.com/user-attachments/assets/91919d79-daf7-4271-b40e-43354ec5c032)

## Applying Pixel filter
![MyPixelFX.fx](https://github.com/user-attachments/assets/f42aa4a4-0aae-4521-ac85-879eb9206a5d)

## Applying Kuwahara filter
![KuwaharaFilter.fx](https://github.com/user-attachments/assets/a7531b04-b86b-47a0-b0bf-24be3df5d7c7)

## Applying Kuwahara filter + Pixel filter
![KuwaharaFilter.fx + MyPixelFX.fx](https://github.com/user-attachments/assets/896730e2-b3ae-42ae-9ffe-a57b41ff00d1)
)


