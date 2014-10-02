//@author: tmp
//@help: Projects a texture on a given geometry
//@tags: Projection
//@credits: 

// --------------------------------------------------------------------------------------------------
// PARAMETERS:
// --------------------------------------------------------------------------------------------------
Texture2D texture2d <string uiname="Texture";>;

SamplerState linearSampler : IMMUTABLE
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};
 
cbuffer cbPerDraw : register( b0 )
{
	float4x4 tV: VIEW;
	float4x4 tP: PROJECTION;
	float4x4 tVP : VIEWPROJECTION;
	float4x4 tWVP: WORLDVIEWPROJECTION;
};

cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
	int Index;
	int ViewIndex: VIEWPORTINDEX;
	int ViewCount: VIEWPORTCOUNT;
	float4x4 tTexView <string uiname="Texture View Transform";>;                  //Texture Transform
	float4x4 tTexProj <string uiname="Texture Projection Transform";>;                  //Texture Transform
	float4x4 tTexViewPort <string uiname="Texture ViewPort Transform";>;
};

float px = 1.0/1024;
float py = 1.0/1024;

struct VS_IN
{
	float4 PosO : POSITION;
	float4 TexCd : TEXCOORD0;

};

struct vs2ps
{
    float4 Pos: SV_POSITION;
    float4 TexCV: TEXCOORD0;
	float4 TexCP: TEXCOORD1;
	float4 TexCS: TEXCOORD2;
};

// --------------------------------------------------------------------------------------------------
// VERTEXSHADERS
// --------------------------------------------------------------------------------------------------

void TransformTex(
    float4 TexC,
    float4x4 tTexView,
    float4x4 tTexProj,
    float4x4 tTexViewPort,
    out float4 VTexC,
    out float4 PTexC,
    out float4 STexC)
{
    VTexC = mul(TexC, tTexView);
    PTexC = mul(VTexC, tTexProj);
    STexC = mul(PTexC, tTexViewPort);
    STexC = mul(STexC,
      float4x4( 0.5,  0.0, 0.0, 0.0,
                0.0, -0.5, 0.0, 0.0,
                0.0,  0.0, 1.0, 0.0,
                0.5,  0.5, 0.0, 1.0 ));
}

vs2ps VS(VS_IN input)
{
    vs2ps Out = (vs2ps)0;
	
	//transform position, if not in viewport, then resize mesh subset to zero
	if (asuint(Index)%asuint(ViewCount) == asuint(ViewIndex)) {
		Out.Pos = mul(input.PosO, tWVP);
    }
	else {
		Out.Pos = 0;
	}    
    
	
	
	//transform texturecoordinates
    float4 TexC = input.PosO;
    TexC = mul(TexC, tW);
    TransformTex(TexC, tTexView, tTexProj, tTexViewPort, Out.TexCV, Out.TexCP, Out.TexCS);
	
    return Out;
}


// --------------------------------------------------------------------------------------------------
// PIXELSHADERS:
// --------------------------------------------------------------------------------------------------

float InCone(float3 TexCP)
{
    return max(sign(1-abs(TexCP.x)), 0.0) *
           max(sign(1-abs(TexCP.y)), 0.0) *
           max(sign(0.5-abs(TexCP.z-0.5)), 0.0);
}

float4 PS4(vs2ps In): SV_Target
{
    In.TexCP.xyz = In.TexCP.xyz / In.TexCP.w;
	float3 col = InCone(In.TexCP.rgb);
    In.TexCS.xyz = In.TexCS.xyz / In.TexCS.w;
	
    float4 c = texture2d.Sample(linearSampler,In.TexCS.xy);
	c += texture2d.Sample(linearSampler,In.TexCS.xy + float2( px, 0 ));
    c += texture2d.Sample(linearSampler,In.TexCS.xy - float2( px, 0 ));
	c += texture2d.Sample(linearSampler,In.TexCS.xy + float2( 0, py ));
	c += texture2d.Sample(linearSampler,In.TexCS.xy - float2( 0, py ));
	
    col *= c.rgb/6;
    return float4(col, 1);
}

float4 PS(vs2ps In): SV_Target
{
    In.TexCP.xyz = In.TexCP.xyz / In.TexCP.w;
    float3 col = InCone(In.TexCP.rgb);

    In.TexCS.xyz = In.TexCS.xyz / In.TexCS.w;

    col *= texture2d.Sample(linearSampler,In.TexCS.xy).rgb;
    return float4(col, 1);
}



technique10 TProject_sample4neighbours
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS4() ) );
	}
}

technique10 TProject
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS() ) );
	}
}




