struct FragmentInput
{
	float4 Color : COLOR0;
};

cbuffer UniformBlock : register(b0, space3)
{
	float Time;
};

float4 main(FragmentInput input) : SV_Target0
{
	float pulse = sin(Time * 3.0) * 0.5 + 0.5;

	return float4(input.Color.rgb * (0.8 + pulse * 0.5), input.Color.a);
}
