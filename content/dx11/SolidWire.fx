

float4x4 tW: WORLD;
float4x4 tWV: WORLDVIEW;
float4x4 tWVP: WORLDVIEWPROJECTION;
float4x4 tWVIT:WORLDVIEWINVERSETRANSPOSE;
float4x4 tV: VIEW;
float4x4 tVI: VIEWINVERSE;
float4x4 tP: PROJECTION;

float LineWidth = 1.5;
float FadeDistance = 50;
float PatternPeriod = 1.5;

float4 FillColor  <bool color=true; String uiname="FillColor";>  = {0.1, 0.2, 0.4, 1};
float4 WireColor  <bool color=true;String uiname="WireColor";>  = {1, 1, 1, 1};
float4 PatternColor  <bool color=true;String uiname="PatternColor";>  = {1, 1, 0.5, 1};
float4 LightVector <string uiname="LightVector";> = {0, 0, 1, 0}; 

DepthStencilState DSSDepthWriteLess
{
  DepthEnable = true;
  DepthWriteMask = All;
  DepthFunc = Less;
};

DepthStencilState DSSDepthLessEqual
{
  DepthEnable = true;
  DepthWriteMask = 0x00;
  DepthFunc = Less_Equal;
};

RasterizerState RSFill
{
    FillMode = SOLID;
    CullMode = None;
    DepthBias = false;
    MultisampleEnable = true;
};

RasterizerState RSFillBiasBack
{
    FillMode = SOLID;
    CullMode = None;
    DepthBias = 1000;
    DepthBiasClamp = 10000;
    SlopeScaledDepthBias = 2;
    MultisampleEnable = true;
};

RasterizerState RSWireframe
{
    FillMode = WIREFRAME;
    CullMode = None;
    DepthBias = false;
    AntialiasedLineEnable = false;
    MultisampleEnable = true;
};

RasterizerState RSWireframeAntialiased
{
    FillMode = WIREFRAME;
    CullMode = None;
    DepthBias = false;
    AntialiasedLineEnable = true;
    MultisampleEnable = true;
};

BlendState BSNoColor
{
    BlendEnable[0] = false;
    RenderTargetWriteMask[0] = 0x00;
};

BlendState BSBlending
{
    BlendEnable[0] = TRUE;
    SrcBlend = SRC_ALPHA;
    DestBlend = INV_SRC_ALPHA ;
    BlendOp = ADD;
    SrcBlendAlpha = SRC_ALPHA;
    DestBlendAlpha = DEST_ALPHA;
    BlendOpAlpha = ADD;
    RenderTargetWriteMask[0] = 0x0F;
};



#include "cktools.fx"



struct VS_INPUT
{
    float3 Pos  : POSITION;
    float3 Nor  : NORMAL;
    float3 Tex  : TEXCOORD0;
};

struct GS_INPUT
{
    float4 Pos  : POSITION;
    float4 PosV : TEXCOORD0;
};

struct PS_INPUT
{
    float4 Pos : SV_POSITION;
    float4 Col : TEXCOORD0;
};

struct PS_INPUT_WIRE
{
    float4 Pos : SV_POSITION;
    float4 Col : TEXCOORD0;
    float3 Heights : TEXCOORD1;
};

//--------------------------------------------------------------------------------------
// Utils Funtions
//--------------------------------------------------------------------------------------

// Compute the final color of a face depending on its facing of the light
float4 shadeFace(in float4 verA, in float4 verB, in float4 verC)
{
    // Compute the triangle face normal in view frame
    float3 normal = faceNormal(verA.xyz, verB.xyz, verC.xyz);
    
    // Then the color of the face.
    float shade = 0.5*abs( dot( normal.xyz, LightVector.xyz) );
    
    return float4(FillColor.xyz*shade, 1);
}

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------
GS_INPUT VS( VS_INPUT input )
{
    GS_INPUT output;
    output.Pos = modelToProj( float4(input.Pos, 1));
    output.PosV = modelToView( float4(input.Pos, 1));
    return output;
}

//--------------------------------------------------------------------------------------
// Geometry Shader
//--------------------------------------------------------------------------------------

[maxvertexcount(3)] 
void GS( triangle GS_INPUT input[3],
         inout TriangleStream<PS_INPUT> outStream )
{
    PS_INPUT output;

    // Shade and colour face.
    output.Col = shadeFace(input[0].PosV, input[1].PosV, input[2].PosV);

    output.Pos = input[0].Pos;
    outStream.Append( output );

    output.Pos = input[1].Pos;
    outStream.Append( output );

    output.Pos = input[2].Pos;
    outStream.Append( output );

    outStream.RestartStrip();
}

[maxvertexcount(3)]
void GSSolidWire( triangle GS_INPUT input[3],
                         inout TriangleStream<PS_INPUT_WIRE> outStream )
{
    PS_INPUT_WIRE output;

    // Shade and colour face.
    output.Col = shadeFace(input[0].PosV, input[1].PosV, input[2].PosV);

    // Emit the 3 vertices
    // The Height attribute is based on the constant
    output.Pos = input[0].Pos;
    output.Heights = float3( 1, 0, 0 );
    outStream.Append( output );

    output.Pos = input[1].Pos;
    output.Heights = float3( 0, 1, 0 );
    outStream.Append( output );

    output.Pos = input[2].Pos;
    output.Heights = float3( 0, 0, 1 );
	outStream.Append( output );

    outStream.RestartStrip();
}

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------

float4 PSColor( PS_INPUT input) : SV_Target
{
    return input.Col;
}

float4 PSDXWire( PS_INPUT input) : SV_Target
{
    return WireColor;
}

float evalMinDistanceToEdges(in PS_INPUT_WIRE input)
{
    float dist;

	float3 ddxHeights = ddx( input.Heights );
	float3 ddyHeights = ddy( input.Heights );
	float3 ddHeights2 =  ddxHeights*ddxHeights + ddyHeights*ddyHeights;
	
    float3 pixHeights2 = input.Heights *  input.Heights / ddHeights2 ;
    
    dist = sqrt( min ( min (pixHeights2.x, pixHeights2.y), pixHeights2.z) );
    
    return dist;
}

float4 PSSolidWire( PS_INPUT_WIRE input) : SV_Target
{
    // Compute the shortest distance between the fragment and the edges.
    float dist = evalMinDistanceToEdges(input);

    // Cull fragments too far from the edge.
    if (dist > 0.5*LineWidth+1) discard;

    // Map the computed distance to the [0,2] range on the border of the line.
    dist = clamp((dist - (0.5*LineWidth - 1)), 0, 2);

    // Alpha is computed from the function exp2(-2(x)^2).
    dist *= dist;
    float alpha = exp2(-2*dist);

    // Standard wire color
    float4 color = WireColor;
    color.a *= alpha;
	
    return color;
}

float4 PSSolidWireFade( PS_INPUT_WIRE input) : SV_Target
{
    // Compute the shortest square distance between the fragment and the edges.
    float dist = evalMinDistanceToEdges(input);

    // Cull fragments too far from the edge.
    if (dist > 0.5*LineWidth+1) discard;

    // Map the computed distance to the [0,2] range on the border of the line.
    dist = clamp((dist - (0.5*LineWidth - 1)), 0, 2);

    // Alpha is computed from the function exp2(-2(x)^2).
    dist *= dist;
    float alpha = exp2(-2*dist);

    // Standard wire color but faded by distance
    // Dividing by pos.w, the depth in view space
    float fading = clamp(FadeDistance / input.Pos.w, 0, 1);

    float4 color = WireColor * fading;
    color.a *= alpha;
    return color;
}

float det( float2 a, float2 b )
{
	return (a.x*b.y - a.y*b.x);
}

float4 PSSolidWirePattern( PS_INPUT_WIRE input) : SV_Target
{
    // Compute the shortest square distance between the fragment and the edges.
    float3 eDists;
    float3 vDists;
    uint3 order = uint3(0, 1, 2);

    float dist;

	float3 ddxHeights = ddx( input.Heights );
	float3 ddyHeights = ddy( input.Heights );
	float3 invddHeights = 1.0 / sqrt( ddxHeights*ddxHeights + ddyHeights*ddyHeights );

    eDists = input.Heights * invddHeights ;
    vDists = (1.0 - input.Heights) * invddHeights ;
    
	if (eDists[1] < eDists[0])
	{
		order.xy = order.yx;
	}
	if (eDists[2] < eDists[order.y])
	{
		order.yz = order.zy;
	}
	if (eDists[2] < eDists[order.x])
	{
		order.xy = order.yx;
	}
	
	// Now compute the coordinate of the fragment along each edges
   
	float2 hDirs[3] ;
	hDirs[0] = float2( ddxHeights[0], ddyHeights[0] ) * invddHeights[0] ;
 	hDirs[1] = float2( ddxHeights[1], ddyHeights[1] ) * invddHeights[1] ;
	hDirs[2] = float2( ddxHeights[2], ddyHeights[2] ) * invddHeights[2] ;
   
	float2 hTans[3] ;
	hTans[0] = float2( - hDirs[0].y, hDirs[0].x ) ;
 	hTans[1] = float2( - hDirs[1].y, hDirs[1].x ) ;
	hTans[2] = float2( - hDirs[2].y, hDirs[2].x ) ;
   
	float2 ePoints[3] ;
	ePoints[0] = input.Pos.xy - hDirs[0]*eDists[0];
	ePoints[1] = input.Pos.xy - hDirs[1]*eDists[1];
	ePoints[2] = input.Pos.xy - hDirs[2]*eDists[2];

	float2 eCoords[3] ;
	eCoords[0].x = det( hTans[1], ePoints[0] - ePoints[1] ) / det( hTans[0], hTans[1] );
	eCoords[0].y = det( hTans[2], ePoints[0] - ePoints[2] ) / det( hTans[0], hTans[2] );
	
	eCoords[1].x = det( hTans[2], ePoints[1] - ePoints[2] ) / det( hTans[1], hTans[2] );
	eCoords[1].y = det( hTans[0], ePoints[1] - ePoints[0] ) / det( hTans[1], hTans[0] );

	eCoords[2].x = det( hTans[0], ePoints[2] - ePoints[0] ) / det( hTans[2], hTans[0] );
	eCoords[2].y = det( hTans[1], ePoints[2] - ePoints[1] ) / det( hTans[2], hTans[1] );
	

    float2 edgeCoord;
	
	// Current coordinate along closest edge in pixels
	edgeCoord.x = abs(eCoords[order.x].x);
	// Length of the closest edge in pixels
	edgeCoord.y = abs(eCoords[order.x].y - eCoords[order.x].x );
  
    dist = eDists[order.x];
    
    // Standard wire color
    float4 color = WireColor;
    float realLineWidth = 0.5*LineWidth;

    // if on the diagonal edge apply pattern
    if ( 2 == order.x )
    {
        if (dist > LineWidth+1) discard;

        float patternPos = (abs(edgeCoord.x - 0.5 * edgeCoord.y)) % (PatternPeriod * 2 * LineWidth) - PatternPeriod * LineWidth;
        dist = sqrt(patternPos*patternPos + dist*dist);

        color = PatternColor;
        realLineWidth = LineWidth;

        // Filling the corners near the vertices with the WireColor
        if ( eDists[order.y] < (0.5*LineWidth+1) )
        {
            dist = eDists[order.y];
            color = WireColor;
            realLineWidth = 0.5*LineWidth;
        }
    }
    // Cull fragments too far from the edge.
    else if (dist > 0.5*LineWidth+1) discard;

    // Map the computed distance to the [0,2] range on the border of the line.
    dist = clamp((dist - (realLineWidth - 1)), 0, 2);

    // Alpha is computed from the function exp2(-2(x)^2).
    dist *= dist;
    float alpha = exp2(-2*dist);

    color.a *= alpha;
    return color;
}

//--------------------------------------------------------------------------------------

technique10 DephAndSolid
{
    pass
    {
        SetDepthStencilState( DSSDepthWriteLess, 0 );
        SetRasterizerState( RSFill );
        SetBlendState( BSBlending, float4( 0.0f, 0.0f, 0.0f, 0.0f ), 0xFFFFFFFF );
        SetVertexShader( CompileShader( vs_4_0, VS() ) );
        SetGeometryShader( CompileShader( gs_4_0, GS() ) );
        SetPixelShader( CompileShader( ps_4_0, PSColor() ) );
    }
}

technique10 DephAndSolidBiased
{
    pass
    {
        SetDepthStencilState( DSSDepthWriteLess, 0 );
        SetRasterizerState( RSFillBiasBack );
        SetBlendState( BSBlending, float4( 0.0f, 0.0f, 0.0f, 0.0f ), 0xFFFFFFFF );
        SetVertexShader( CompileShader( vs_4_0, VS() ) );
        SetGeometryShader( CompileShader( gs_4_0, GS() ) );
        SetPixelShader( CompileShader( ps_4_0, PSColor() ) );
    }
}

technique10 DepthOnly
{
    pass
    {
        SetDepthStencilState( DSSDepthWriteLess, 0 );
        SetRasterizerState( RSFill );
        SetBlendState( BSNoColor, float4( 0.0f, 0.0f, 0.0f, 0.0f ), 0xFFFFFFFF );
        SetVertexShader( CompileShader( vs_4_0, VS() ) );
        SetGeometryShader( CompileShader( gs_4_0, GS() ) );
        SetPixelShader( CompileShader( ps_4_0, PSColor() ) );
    }
}

technique10 DepthOnlyBiased
{
    pass
    {
        SetDepthStencilState( DSSDepthWriteLess, 0 );
        SetRasterizerState( RSFillBiasBack );
        SetBlendState( BSNoColor, float4( 0.0f, 0.0f, 0.0f, 0.0f ), 0xFFFFFFFF );
        SetVertexShader( CompileShader( vs_4_0, VS() ) );
        SetGeometryShader( CompileShader( gs_4_0, GS() ) );
        SetPixelShader( CompileShader( ps_4_0, PSColor() ) );
    }
}

technique10 SolidOnly
{
    pass
    {
        SetDepthStencilState( DSSDepthLessEqual, 0 );
        SetRasterizerState( RSFill );
        SetBlendState( BSBlending, float4( 0.0f, 0.0f, 0.0f, 0.0f ), 0xFFFFFFFF );
        SetVertexShader( CompileShader( vs_4_0, VS() ) );
        SetGeometryShader( CompileShader( gs_4_0, GS() ) );
        SetPixelShader( CompileShader( ps_4_0, PSColor() ) );
    }
}


//--------------------------------------------------------------------------------------

technique10 DXWire
    <string info = "DXWire : Classic DirectX line rendering";>
{
    pass
    {
        SetDepthStencilState( DSSDepthLessEqual, 0 );
        SetRasterizerState( RSWireframe );
        SetBlendState( BSBlending, float4( 0.0f, 0.0f, 0.0f, 0.0f ), 0xFFFFFFFF );
        SetVertexShader( CompileShader( vs_4_0, VS() ) );
        SetGeometryShader( CompileShader( gs_4_0, GS() ) );
        SetPixelShader( CompileShader( ps_4_0, PSDXWire() ) );
    }
}

technique10 DXWireAntialiased
    <string info = "DXWire : Classic DirectX line rendering with line antialiasing";>
{
    pass
    {
        SetDepthStencilState( DSSDepthLessEqual, 0 );
        SetRasterizerState( RSWireframeAntialiased );
        SetBlendState( BSBlending, float4( 0.0f, 0.0f, 0.0f, 0.0f ), 0xFFFFFFFF );
        SetVertexShader( CompileShader( vs_4_0, VS() ) );
        SetGeometryShader( CompileShader( gs_4_0, GS() ) );
        SetPixelShader( CompileShader( ps_4_0, PSDXWire() ) );
    }
}

technique10 SolidWire
    <string info = "SolidWire technique";>
{     
    pass
    {
        SetDepthStencilState( DSSDepthLessEqual, 0 );
        SetRasterizerState( RSFill );
        SetBlendState( BSBlending, float4( 0.0f, 0.0f, 0.0f, 0.0f ), 0xFFFFFFFF );
        SetVertexShader( CompileShader( vs_4_0, VS() ) );
        SetGeometryShader( CompileShader( gs_4_0, GSSolidWire() ) );
        SetPixelShader( CompileShader( ps_4_0, PSSolidWire() ) );
    }
}

technique10 SolidWireFade
    <string info = "SolidWireFade : SolidWire fragments faded depending on the depth";>
{     
    pass
    {
        SetDepthStencilState( DSSDepthLessEqual, 0 );
        SetRasterizerState( RSFill );
        SetBlendState( BSBlending, float4( 0.0f, 0.0f, 0.0f, 0.0f ), 0xFFFFFFFF );
        SetVertexShader( CompileShader( vs_4_0, VS() ) );
        SetGeometryShader( CompileShader( gs_4_0, GSSolidWire() ) );
        SetPixelShader( CompileShader( ps_4_0, PSSolidWireFade() ) );
    }
}

technique10 SolidWirePattern
    <string info = "SolidWirePattern : SolidWire with a dot line pattern on diagonal edges";>
{
    pass
    {
        SetDepthStencilState( DSSDepthLessEqual, 0 );
        SetRasterizerState( RSFill );
        SetBlendState( BSBlending, float4( 0.0f, 0.0f, 0.0f, 0.0f ), 0xFFFFFFFF );
        SetVertexShader( CompileShader( vs_4_0, VS() ) );
        SetGeometryShader( CompileShader( gs_4_0, GSSolidWire() ) );
        SetPixelShader( CompileShader( ps_4_0, PSSolidWirePattern() ) );
    }
}

