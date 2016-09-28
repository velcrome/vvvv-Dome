//----------------------------------------------------------------------------------
// File:   CkTools.cpp
// Author: Samuel Gateau
// Email:  sdkfeedback@nvidia.com
// 
// Copyright (c) 2007 NVIDIA Corporation. All rights reserved.
//
// TO  THE MAXIMUM  EXTENT PERMITTED  BY APPLICABLE  LAW, THIS SOFTWARE  IS PROVIDED
// *AS IS*  AND NVIDIA AND  ITS SUPPLIERS DISCLAIM  ALL WARRANTIES,  EITHER  EXPRESS
// OR IMPLIED, INCLUDING, BUT NOT LIMITED  TO, IMPLIED WARRANTIES OF MERCHANTABILITY
// AND FITNESS FOR A PARTICULAR PURPOSE.  IN NO EVENT SHALL  NVIDIA OR ITS SUPPLIERS
// BE  LIABLE  FOR  ANY  SPECIAL,  INCIDENTAL,  INDIRECT,  OR  CONSEQUENTIAL DAMAGES
// WHATSOEVER (INCLUDING, WITHOUT LIMITATION,  DAMAGES FOR LOSS OF BUSINESS PROFITS,
// BUSINESS INTERRUPTION, LOSS OF BUSINESS INFORMATION, OR ANY OTHER PECUNIARY LOSS)
// ARISING OUT OF THE  USE OF OR INABILITY  TO USE THIS SOFTWARE, EVEN IF NVIDIA HAS
// BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
//
//
//----------------------------------------------------------------------------------

// helper struct and functions for demo.

//--------------------------------------------------------------------------------------
// Standard pixel shader input structures
//--------------------------------------------------------------------------------------

struct PS_DrawTool
{
    float4 Pos : SV_POSITION;
    float3 Tex : TEXCOORD1;
    float4 Col : TEXCOORD2;
};

//--------------------------------------------------------------------------------------
// Standard Transform Parameters
//--------------------------------------------------------------------------------------

float4 Frustum;
float4 Viewport;

//--------------------------------------------------------------------------------------
// Standard Transform Functions
//--------------------------------------------------------------------------------------
float4 modelToProj(in float4 pos)
{
    return mul(pos, tWVP);
}

float4 modelToView(in float4 pos)
{
    return mul(pos, tWV);
}

float4 viewToProj(in float4 pos)
{
    return mul(pos, tP);
}

float4 viewToProj2(in float4 pos)
{
    return float4(	pos.x * 2 * Frustum.z / Frustum.x, 
					pos.y * 2 * Frustum.z / Frustum.y,
					(Frustum.w / (Frustum.w - Frustum.z)) * ( pos.z - pos.w*Frustum.z ),
					pos.z );
}

// From window pixel pos to projection frame at the specified z (view frame). 
float2 projToWindow(in float4 pos)
{
    return float2(  Viewport.x*0.5*((pos.x/pos.w) + 1) + Viewport.z,
                    Viewport.y*0.5*(1-(pos.y/pos.w)) + Viewport.w );
}

// From window pixel pos to projection frame at the specified z (view frame). 
float4 windowToProj(in float2 pos, float depth)
{
    return float4(  (((pos.x-Viewport.z)*2/Viewport.x)-1)*depth,
                    (((pos.y-Viewport.w)*2/Viewport.y)-1)*(-depth),
                    (depth - Frustum.z)*Frustum.w /(Frustum.w - Frustum.z),
                    depth );
}

//--------------------------------------------------------------------------------------
// Standard Geometric Functions
//--------------------------------------------------------------------------------------

// Compute the triangle face normal from 3 points
float3 faceNormal(in float3 posA, in float3 posB, in float3 posC)
{
    return normalize( cross(normalize(posB - posA), normalize(posC - posA)) );
}


//--------------------------------------------------------------------------------------
// Generate sprite and line Funtions
//--------------------------------------------------------------------------------------

// Make a quad sprite of the specified pixel width from 1 point in the projection frame.
void makeSprite(out float4 points[4], in float4 pos, in float width)
{
    // Bring A in window space
    float2 Aw = projToWindow(pos);

    // Compute diagonals of sprite quad in window space
    // Binormal is scaled by line width 
    float2 diag1 = float2(0.5*width, 0.5*width);
    float2 diag2 = float2(diag1.x, -diag1.y);
    
    // Compute the corners of the sprite in window space
    float2 A1w = (Aw - diag1);
    float2 A2w = (Aw + diag2);
    float2 B1w = (Aw - diag2);
    float2 B2w = (Aw + diag1);

    // bring back corners in projection frame
    points[0] = windowToProj(A1w, pos.w);
    points[1] = windowToProj(A2w, pos.w);
    points[2] = windowToProj(B1w, pos.w);
    points[3] = windowToProj(B2w, pos.w);
}

// Make a a ribbon line of the specified pixel width from 2 points in the projection frame.
void makeLine(out float4 points[4], in float4 posA, in float4 posB, in float width)
{
    // Bring A and B in window space
    float2 Aw = projToWindow(posA);
    float2 Bw = projToWindow(posB);

    // Compute tangent and binormal of line AB in window space
    // Binormal is scaled by line width 
    float2 tangent = normalize(Bw.xy - Aw.xy);
    float2 binormal = 0.5*width * float2(tangent.y, -tangent.x);
    
    // Compute the corners of the ribbon in window space
    float2 A1w = (Aw - binormal);
    float2 A2w = (Aw + binormal);
    float2 B1w = (Bw - binormal);
    float2 B2w = (Bw + binormal);

    // bring back corners in projection frame
    points[0] = windowToProj(A1w, posA.w);
    points[1] = windowToProj(A2w, posA.w);
    points[2] = windowToProj(B1w, posB.w);
    points[3] = windowToProj(B2w, posB.w);
}
 
//--------------------------------------------------------------------------------------
// Drawing sprite and line Geometry Shader + Pixel Shader Funtions
//--------------------------------------------------------------------------------------

void GSDrawSprite(in float4 pos, in float width, in PS_DrawTool output, inout TriangleStream<PS_DrawTool> outStream, in float texcoord = 1)
{
    float4 spriteCorners[4];
    makeSprite(spriteCorners, pos, width);

    output.Pos = spriteCorners[0];
    output.Tex[0] = -texcoord;
    output.Tex[1] = -texcoord;
    output.Tex[2] = 0;
    outStream.Append( output );
    
    output.Pos = spriteCorners[1];
    output.Tex[0] = texcoord;
    output.Tex[1] = -texcoord;
    outStream.Append( output );
 
    output.Pos = spriteCorners[2];
    output.Tex[0] = -texcoord;
    output.Tex[1] = texcoord;
    output.Tex[2] = 0;
    outStream.Append( output );
    
    output.Pos = spriteCorners[3];
    output.Tex[0] = texcoord;
    output.Tex[1] = texcoord;
    outStream.Append( output );
    
    outStream.RestartStrip();
}

void GSDrawVector(in float4 pos, in float4 vec, in float width, in PS_DrawTool output, inout TriangleStream<PS_DrawTool> outStream )
{
    float4 lineCorners[4];
    makeLine(lineCorners, pos, pos+vec, width);

    output.Pos = lineCorners[0];
    output.Tex[0] = -1;
    output.Tex[1] = 1;
    output.Tex[2] = 0;
    outStream.Append( output );
    
    output.Pos = lineCorners[1];
    output.Tex[0] = 1;
    output.Tex[1] = -1;
    outStream.Append( output );
 
    output.Pos = lineCorners[2];
    output.Tex[0] = -1;
    output.Tex[1] = 1;
    output.Tex[2] = 1;
    outStream.Append( output );
    
    output.Pos = lineCorners[3];
    output.Tex[0] = 1;
    output.Tex[1] = -1;
    outStream.Append( output );
    
    outStream.RestartStrip();
}



float4 PSDrawTool( PS_DrawTool input) : SV_Target
{
    float arrowScale = 1 / (0.25 + (input.Tex[2]>0.9)*(-input.Tex[2]+1)*10);

    // Compute distance of the fragment to the edges    
    float alpha = min(abs(input.Tex[0]), abs(input.Tex[1]));
    float dist = arrowScale * alpha;
    alpha = exp2(-4*dist*dist*dist*dist);
    
    float4 color = input.Col;
    color.a *= alpha;
    return color;
}