int f();

kernel void clear_screen(__write_only image2d_t text)
{
	int2 imgCoords = (int2)(get_global_id(0), get_global_id(1));
 
	float4 imgVal = (float4)((imgCoords.x % 255) / 255.0f, (imgCoords.y % 255) / 255.0f, f(), 1.0f);
 
	write_imagef(text, imgCoords, imgVal);
}
