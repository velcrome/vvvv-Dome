//@author: sebl
//@help: elevation contour lines in 3 dimensions
//@tags: 
//@credits: Nvidia corp.

float Alpha;

cbuffer cbPerDraw : register( b0 )
{
	float4x4 tVP : VIEWPROJECTION;
};


cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
	
	float4x4 trans;
	
	float Width;
	float Scale;
	float Balance;
	
	float4 SurfColor1 <bool color=true;String uiname="SurfColor1";> = { 1.0f,1.0f,1.0f,1.0f };
	float4 SurfColor2 <bool color=true;String uiname="SurfColor2";> = { 1.0f,1.0f,1.0f,1.0f };
	
	bool EnableX<String uiname="X";> = { true };
	bool EnableY<String uiname="Y";> = { true };
	bool EnableZ<String uiname="Z";> = { true };
};


struct VS_IN
{
	float4 PosO 	: POSITION;
};

struct vs2ps
{
	float4 PosWVP	: SV_POSITION;
	float3 PosW		: TEXCOORD0;
	float4 ObjPos	: TEXCOORD1;
};

vs2ps VS(VS_IN input)
{
	vs2ps Out = (vs2ps)0;
	Out.PosWVP  = mul(input.PosO,mul(tW,tVP));
	Out.PosW = mul(input.PosO, tW).xyz;
	
	float4 Po = float4(input.PosO.xyz,1.0);
	Out.ObjPos = Po;
	
	return Out;
}




float4 PS(vs2ps In): SV_Target
{
	In.ObjPos = mul(In.ObjPos, trans);
	
	float op = Width/Scale;
	float edge = Scale*Balance;
	
	float width;
	float w;
	float x0;
	float x1;
	float nedge;
	float i0;
	float i1;
	float check = 0;
	float s;
	
	// x stripes
	if(EnableX == true)
	{
		width = abs(ddx(In.ObjPos.x)) + abs(ddy(In.ObjPos.x));
		w = width*op;
		x0 = In.ObjPos.x/Scale - (w/2.0);
		x1 = x0 + w;
		nedge = edge/Scale;
		i0 = (1.0-nedge)*floor(x0) + max(0.0, frac(x0)-nedge);
		i1 = (1.0-nedge)*floor(x1) + max(0.0, frac(x1)-nedge);
		check = (i1 - i0)/w;
		check = min(1.0,max(0.0,check));
	}
	
	// y stripes
	if(EnableY == true)
	{
		width = abs(ddx(In.ObjPos.y)) + abs(ddy(In.ObjPos.y));
		w = width*op;
		x0 = In.ObjPos.y/Scale - (w/2.0);
		x1 = x0 + w;
		nedge = edge/Scale;
		i0 = (1.0-nedge)*floor(x0) + max(0.0, frac(x0)-nedge);
		i1 = (1.0-nedge)*floor(x1) + max(0.0, frac(x1)-nedge);
		s = (i1 - i0)/w;
		//		check = abs(check - min(1.0,max(0.0,s)));
		check += s;
	}
	
	// z stripes
	if(EnableZ == true)
	{
		width = abs(ddx(In.ObjPos.z)) + abs(ddy(In.ObjPos.z));
		w = width*op;
		x0 = In.ObjPos.z/Scale - (w/2.0);
		x1 = x0 + w;
		nedge = edge/Scale;
		i0 = (1.0-nedge)*floor(x0) + max(0.0, frac(x0)-nedge);
		i1 = (1.0-nedge)*floor(x1) + max(0.0, frac(x1)-nedge);
		s = (i1 - i0)/w;
		//		check = abs(check - min(1.0,max(0.0,s)));
		check += s;
	}
	
	float4 dColor = lerp(SurfColor1,SurfColor2,check);
	dColor.a *= Alpha;
	
	return dColor;
	
	
	
	/*
	//	float3 worldPosition = mul(In.Pos, tW).xyz;
	//	float3 worldPosition = mul(In.PosWVP, mul(tWI,tVP)).xyz;
	//	float3 worldPosition = inv(In.PosWVP).xyz;
	float3 worldPosition = In.PosW.xyz;
	
	float4 Color;
	int z = ceil(worldPosition.z);
	int y = ceil(worldPosition.y);
	int x = ceil(worldPosition.x);
	
	//	int z = worldPosition.z;
	//	int y = worldPosition.y;
	//	int x = worldPosition.x;
	Color = float4(0.2, 0.2, 0.2, 0.4);
	
	//	Color.r =  abs(x );
	
	if(x > dist.x) Color.r = 1;
	
	//	if(abs(fmod(x, dist.x))<1.0)
	//	{
		//		Color.r = 1.0f;
	//		Color.g = 0.0f;
	//		Color.b = 0.0f;
	//		Color.a = 1.0f;
	//	}
	//	if(abs(fmod(y, dist.y))<1.0)
	//	{
		//		Color.r = 0.0f;
	//		Color.g = 1.0f;
	//		Color.b = 0.0f;
	//		Color.a = 1.0f;
	//	}
	//	if(abs(fmod(z, dist.z))<1.0)
	//	{
		//		Color.r = 0.0f;
	//		Color.g = 0.0f;
	//		Color.b = 1.0f;
	//		Color.a = 1.0f;
	//	}
	
	return Color;*/
}





technique10 Elevation
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS() ) );
	}
}




