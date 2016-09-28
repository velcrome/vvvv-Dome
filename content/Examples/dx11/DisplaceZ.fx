//@author: antokhio 
//@help: template
//@tags: template 
//@credits: vvvv

Texture2D texture2d <string uiname="Texture";>; 

float4x4 tW : WORLD;
float4x4 tVP : VIEWPROJECTION;

SamplerState sPoint : IMMUTABLE
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};

float Alpha <float uimin=0.0; float uimax=1.0;> = 1; 
float4 cAmb <bool color=true;String uiname="Color";> = { 1.0f,1.0f,1.0f,1.0f };
float4x4 tTex <string uiname="Texture Transform";>;
float4x4 tColor <string uiname="Color Transform";>;

struct vsIn
{
	float4 pos : POSITION;
	float4 uv : TEXCOORD0;

};

struct vs2ps
{
    float4 pos: SV_POSITION;
    float4 uv: TEXCOORD0;
};

float Power = 1;
vs2ps VS(vsIn input)
{
    vs2ps output = (vs2ps)0;
     
	input.pos.z +=  texture2d.SampleLevel(sPoint,input.uv,0).r * Power;
	output.pos  = mul(input.pos,mul(tW,tVP));
	output.uv = mul(input.uv, tTex);
   
	
	return output;
}

float4 PS(vs2ps input): SV_Target
{
    float4 col = texture2d.Sample(sPoint,input.uv) * cAmb;
	col.a *= Alpha;
    return col;
}

technique10 Template
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS() ) );
	}
}




