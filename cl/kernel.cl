kernel void clear_screen(__write_only image2d_t text)
{
	int2 imgCoords = (int2)(get_global_id(0), get_global_id(1));
 
	float4 imgVal = (float4)(1.0f, 1.0f, 0.0f, 1.0f);
 
	write_imagef(text, imgCoords, imgVal);
}
