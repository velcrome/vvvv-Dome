
//@author: unc,colorsound
//@help: 
//@tags: 
//@credits: desaxismundi,sanch,milo,readme
// --------------------------------------------------------------------------------------------------
// PARAMETERS:
// --------------------------------------------------------------------------------------------------

//transforms
float4x4 tW: WORLD;        //the models world matrix
float4x4 tV: VIEW;         //view matrix as set via Renderer 
float4x4 tP: PROJECTION;
float4x4 tWV : WORLDVIEW;
float4x4 tWVP: WORLDVIEWPROJECTION;

//light properties

float3 lDir <string uiname="Light Direction";> = {0, -5, 2};        //light direction in world space
float4 lAmb <bool color=true;String uiname="Ambient Color";> = { 0.15, 0.15, 0.15, 1 };
float4 lDiff <bool color=true;String uiname="Diffuse Color";> = { 0.85, 0.85, 0.85, 1};
float4 lSpec<bool color=true;String uiname="Specular Color";> = { 0.35, 0.35, 0.35, 1};

float lPower <String uiname="Power"; float uimin=0.0;> = 25.0;     //shininess of specular highlight

int texSize ;
float normalStrength = 8;
float amount = 0.5 ;
//texture
Texture2D texture2d <string uiname="Texture";>;
Texture2D HeightmapTexture <string uiname="Heightmap";>;

float4x4 tTex <string uiname="Texture Transform";>;
float4x4 tTexDisplace <string uiname="DisplaceT Transform";>;

SamplerState g_samLinearC 
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};
SamplerState g_samLinearW 
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};


struct vs2ps
{
    float4 Pos  : SV_POSITION;
    float2 TexCd : TEXCOORD0;
    float3 LightDirV : TEXCOORD1;
    float3 ViewDirV  : TEXCOORD2;
	float2 TexCdDisplace : TEXCOORD3;
};

// --------------------------------------------------------------------------------------------------
// VERTEXSHADERS
// --------------------------------------------------------------------------------------------------
vs2ps VS(float4 PosO  : POSITION,float4 TexCd : TEXCOORD0)
{
    //inititalize all fields of output struct with 0
    vs2ps Out = (vs2ps)0;
    float4 lookup;

    lookup = mul(TexCd,tTexDisplace);
    lookup.w = 0;

	float3 tx = HeightmapTexture.SampleLevel(g_samLinearW,lookup, 2).rgb;

    PosO.z =  PosO.z + tx.x * amount;
    
    //inverse light direction in view space
    Out.LightDirV = normalize(-mul(lDir,(float3x3)tV));
    
    Out.Pos = mul(PosO,tWVP);

    //transform texturecoordinates
    Out.TexCd = mul(TexCd,tTex);
	
    Out.TexCdDisplace =  mul(TexCd,tTexDisplace);
    Out.ViewDirV = -normalize(mul(PosO,tWV));

    return Out;
}

// --------------------------------------------------------------------------------------------------
// PIXELSHADERS:
// -------------------------------- ------------------------------------------------------------------

float4 PS(vs2ps In): SV_Target
{   float texelSize =  1.0f / texSize ;
	
    float tl = abs(HeightmapTexture.Sample (g_samLinearW, In.TexCdDisplace +texelSize  * float2(-1, -1)).x);   // top left
    float  l = abs(HeightmapTexture.Sample (g_samLinearW, In.TexCdDisplace +texelSize  * float2(-1,  0)).x);   // left
    float bl = abs(HeightmapTexture.Sample (g_samLinearW, In.TexCdDisplace +texelSize  * float2(-1,  1)).x);   // bottom left
    float  t = abs(HeightmapTexture.Sample (g_samLinearW, In.TexCdDisplace +texelSize  * float2( 0, -1)).x);   // top
    float  b = abs(HeightmapTexture.Sample (g_samLinearW, In.TexCdDisplace +texelSize  * float2( 0,  1)).x);   // bottom
    float tr = abs(HeightmapTexture.Sample (g_samLinearW, In.TexCdDisplace +texelSize  * float2( 1, -1)).x);   // top right
    float  r = abs(HeightmapTexture.Sample (g_samLinearW, In.TexCdDisplace +texelSize  * float2( 1,  0)).x);   // right
    float br = abs(HeightmapTexture.Sample (g_samLinearW, In.TexCdDisplace +texelSize  * float2( 1,  1)).x);   // bottom right

    // Compute dx using Sobel:

    //           -1 0 1

    //           -2 0 2

    //           -1 0 1

    float dX = tr + 2*r + br -tl - 2*l - bl;

    // Compute dy using Sobel:

    //           -1 -2 -1

    //            0  0  0

    //            1  2  1

    float dY = bl + 2*b + br -tl - 2*t - tr;

    // Build the normalized normal

    float4 N = float4(normalize(float3(dX, 1.0f / normalStrength, dY)), 1.0f);

    //convert (-1.0 , 1.0) to (0.0 , 1.0), if needed

    float3 NormV;

    //normal in view space
    NormV = mul(N, tWV);
    NormV = normalize(NormV);

    //In.TexCd = In.TexCd / In.TexCd.w; // for perpective texture projections (e.g. shadow maps) ps_2_0

    //lAmb.a = 1;
    //halfvector
    float3 H = normalize(In.ViewDirV + In.LightDirV);

    //compute blinn lighting
    float3 shades = lit(dot(NormV, In.LightDirV), dot(NormV, H), lPower);

    float4 diff = lDiff * shades.y;
    diff.a = 1;

    //reflection vector (view space)
    float3 R = normalize(2 * dot(NormV, In.LightDirV) * NormV - In.LightDirV);
    //normalized view direction (view space)
    float3 V = normalize(In.ViewDirV);

    //calculate specular light
    float4 spec = pow(max(dot(R, V),0), lPower*.2) * lSpec;
    
    float4 col = texture2d.Sample(g_samLinearC,In.TexCd.xy);
	
    col.rgb *= (lAmb + diff) + spec;
    return col;

}

// --------------------------------------------------------------------------------------------------
// TECHNIQUES:
// --------------------------------------------------------------------------------------------------


technique10 HeightMapDN
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS() ) );
	}
}

