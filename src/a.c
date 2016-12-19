#include <OpenCL/opencl.h>
#include <OpenCL/cl_ext.h>
#include <OpenCL/cl_gl.h>
#include <OpenCL/cl_gl_ext.h>
#include <OpenCL/gcl.h>
#include <OpenGL/CGLCurrent.h>
#include <xmlx.h>
#include <string.h>
#include <OpenGL/gl.h>
#include <stdio.h>
#include <assert.h>

typedef struct {
	t_xmlx_window *win;
	cl_context ctx;
	cl_command_queue queue;
	cl_program program;
	cl_kernel kernel;
	cl_mem tex_ref;
} t_clctx;

void event_loop(void *up)
{
	t_clctx *ctx = up;
	cl_int e = CL_SUCCESS;
	e = clEnqueueAcquireGLObjects(ctx->queue, 1, &ctx->tex_ref, 0, 0, 0);
	e != CL_SUCCESS && printf("error %d\n", e);
	assert(e == CL_SUCCESS);
/*
  Run kernel here
*/

	e = clSetKernelArg(ctx->kernel, 0, sizeof(cl_mem), &ctx->tex_ref);
	e != CL_SUCCESS && printf("error %d\n", e);
	assert(e == CL_SUCCESS);

	size_t dims[2] = {1280, 720};
	e = clEnqueueNDRangeKernel(ctx->queue, ctx->kernel, 2, 0, dims, 0, 0, 0, 0);
	e != CL_SUCCESS && printf("error %d\n", e);
	assert(e == CL_SUCCESS);

	/*
	  Release the texture
	*/
	e = clEnqueueReleaseGLObjects(ctx->queue, 1, &ctx->tex_ref, 0, 0, 0);
	e != CL_SUCCESS && printf("error %d\n", e);
	assert(e == CL_SUCCESS);
	xmlx_draw(ctx->win);
}

void handle_key(t_xmlx_window *win, int k, int a, int m)
{
	if(k == XMLX_KEY_ESCAPE)
		win->stop = 1;
	(void)a;
	(void)win;
	(void)m;
}

int init_opencl(t_clctx *ctx)
{
	int err = 0;
	cl_uint numDevices;
	clGetDeviceIDs(0, CL_DEVICE_TYPE_GPU, 0, 0, &numDevices);
	cl_device_id devices[numDevices];
	clGetDeviceIDs(0, CL_DEVICE_TYPE_GPU, numDevices, devices, 0);
	int deviceUsed = 0;
	
	CGLContextObj kCGLContext = CGLGetCurrentContext();
	CGLShareGroupObj kCGLShareGroup = CGLGetShareGroup(kCGLContext);

	cl_context_properties properties[] = {
		CL_CONTEXT_PROPERTY_USE_CGL_SHAREGROUP_APPLE,
		(cl_context_properties)kCGLShareGroup, 0
	};

	ctx->ctx = clCreateContext(properties, 1, &devices[deviceUsed], 0, 0, &err);	
	ctx->queue = clCreateCommandQueue(ctx->ctx, devices[deviceUsed], 0, &err);
	size_t len = strlen("kernel.co");
	const unsigned char *file = (void*)"kernel.co";
	ctx->program = clCreateProgramWithBinary(ctx->ctx, 1, &devices[deviceUsed], &len, &file, 0, &err);
	err = clBuildProgram(ctx->program, 1, &devices[deviceUsed], 0, 0, 0);
	ctx->kernel = clCreateKernel(ctx->program, "clear_screen", &err);
	return 1;
}

void destroy_opencl(t_clctx *ctx)
{
	clReleaseKernel(ctx->kernel);
	clReleaseProgram(ctx->program);
	clReleaseCommandQueue(ctx->queue);
	clReleaseContext(ctx->ctx);
}

int main()
{

	t_clctx ctx;
	
	xmlx_init();
	t_xmlx_window *win = xmlx_new_window(1280, 720, "tests", FLOAT4);
	int err;
	ctx.win = win;
	xmlx_present(ctx.win);

	if (!init_opencl(&ctx))
		return 1;

	err = CL_SUCCESS;
	printf("tex: %d\n", ctx.win->framebuffer->tex_id);
	ctx.tex_ref = clCreateFromGLTexture(ctx.ctx, CL_MEM_WRITE_ONLY, GL_TEXTURE_2D, 0, ctx.win->framebuffer->tex_id, &err);
	err != CL_SUCCESS && printf("error %d\n", err);
	assert(err == CL_SUCCESS);
	win->on_key = handle_key;
	xmlx_run_window(win, event_loop, &ctx);

	xmlx_destroy_window(win);
	xmlx_destroy();
	destroy_opencl(&ctx);
}
