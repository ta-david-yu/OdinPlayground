struct VertexInput
{
	float3 Position : POSITION0;
	float4 Color : COLOR0;
};

struct VertexOutput
{
	float4 Position : SV_Position;
	float4 Color : COLOR0;
};

VertexOutput main(VertexInput input)
{
	VertexOutput output;
	output.Position = float4(input.Position, 1.0);
	output.Color = input.Color;
	return output;
}
