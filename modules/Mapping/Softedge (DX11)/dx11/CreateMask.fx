//@author: tmp
//@help: Creates a softedging mask for each projection
//@tags: Softedge, Mask
//@credits: 

Texture2DArray tex <string uiname="Texture";>;

SamplerState linearSampler : IMMUTABLE
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

 
cbuffer cbPerDraw : register( b0 )
{
	float4x4 tVP : VIEWPROJECTION;
};


cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
	int slice;
	int sliceCount;
};

struct vsInput
{
	float4 PosO : POSITION;
	float4 TexCd : TEXCOORD0;

};

struct psInput
{
    float4 PosWVP: SV_POSITION;
    float4 TexCd: TEXCOORD0;
};

psInput VS(vsInput input)
{
    psInput output;
    output.PosWVP  = mul(input.PosO,mul(tW,tVP));
    output.TexCd = input.TexCd;
    return output;
}

float4 PS(psInput input): SV_Target
{
	float4 col = float4(1,1,1,1);
	bool isCovered = false;
	float4 summedCol = float4(0,0,0,0);

	for(int i = 0; i < sliceCount; i++){
		
		// addup values for all projections on this pixel
		float4 s = tex.Sample(linearSampler,float3(input.TexCd.xy,(slice * sliceCount) + i));
		summedCol += s;		
		
		// have a look at all projections except the own
		if(i != slice){ 
			// check if this pixel is covered by another projection
			if (s.r > 0 || s.g > 0 || s.b > 0) isCovered = true;
		}
	}

	// this pixel was covered by another projection and has to be weighted
	if(isCovered){
		float4 sActual = tex.Sample(linearSampler,float3(input.TexCd.xy,(slice * sliceCount) + slice));
		col = sActual / summedCol;
	}
	// this pixel was not covered and remains white
	else col = float4(1,1,1,1);
	
    return col;
}

technique10 Constant
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS() ) );
	}
}




