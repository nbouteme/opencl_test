#if defined (__APPLE__) || defined(MACOSX)
# include <OpenCL/opencl.h>
# include <OpenCL/cl_ext.h>
# include <OpenCL/cl_gl.h>
# include <OpenCL/cl_gl_ext.h>
# include <OpenCL/gcl.h>
# include <OpenGL/CGLCurrent.h>
# include <OpenGL/gl.h>
#else
# define CL_USE_DEPRECATED_OPENCL_1_2_APIS
# include <CL/opencl.h>
# include <CL/cl_ext.h>
# include <CL/cl_gl.h>
# include <CL/cl_gl_ext.h>
# include <GL/gl.h>
# include <GL/glx.h>
#endif

#include <xmlx.h>
#include <string.h>
#include <stdio.h>
#include <assert.h>
#include <sys/stat.h>
#include <sys/fcntl.h>
#include <unistd.h>

typedef struct {
	t_xmlx_window *win;
	cl_context ctx;
	cl_command_queue queue;
	cl_program program;
	cl_kernel kernel;
	cl_mem tex_ref;
} t_clctx;

typedef struct
{
	const unsigned char *start;
	unsigned long *size;
}	t_export_data;

typedef struct
{
	const char *filename;
	t_export_data data;
	void *unused;
}	t_symtable;

typedef struct
{
	const char *module_name;
	t_symtable *syms;
}	t_module;

t_export_data get_embedded_data(const char *name)
{
	extern t_module g_embedded_mod_table[];
	t_module *modptr;
	t_symtable *curmodsyms;

	modptr = g_embedded_mod_table;
	while (modptr->module_name)
	{
		curmodsyms = modptr->syms;
		while (curmodsyms->filename)
		{
			if (strcmp(curmodsyms->filename, name) == 0)
				return (curmodsyms->data);
			++curmodsyms;
		}
		++modptr;
	}
	return ((t_export_data){0, 0});
}

void event_loop(void *up)
{
	t_clctx *ctx = up;
	cl_int e = CL_SUCCESS;
	e = clEnqueueAcquireGLObjects(ctx->queue, 1, &ctx->tex_ref, 0, 0, 0);
	if (e != CL_SUCCESS)
		printf("error %d\n", e);
	assert(e == CL_SUCCESS);
/*
  Run kernel here
*/

	e = clSetKernelArg(ctx->kernel, 0, sizeof(cl_mem), &ctx->tex_ref);
	if (e != CL_SUCCESS)
		printf("error %d\n", e);
	assert(e == CL_SUCCESS);

	size_t dims[2] = {1280, 720};
	e = clEnqueueNDRangeKernel(ctx->queue, ctx->kernel, 2, 0, dims, 0, 0, 0, 0);
	if (e != CL_SUCCESS)
		printf("error %d\n", e);
	assert(e == CL_SUCCESS);

	/*
	  Release the texture
	*/
	e = clEnqueueReleaseGLObjects(ctx->queue, 1, &ctx->tex_ref, 0, 0, 0);
	if (e != CL_SUCCESS)
		printf("error %d\n", e);
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

char *load_from_file(const char *filename)
{
	struct stat s;
	stat(filename, &s);
	void *buf;
	buf = malloc(s.st_size);
	int fd = open(filename, O_RDONLY);
	read(fd, buf, s.st_size);
	close(fd);
	return buf;
}

int init_opencl(t_clctx *ctx)
{
	int err = 0;
	cl_uint nplat = 0;
	err = clGetPlatformIDs(0, 0, &nplat);
	printf("err: %d\n", err);
	cl_platform_id plats[nplat];
	err = clGetPlatformIDs(nplat, plats, 0);

	cl_uint numDevices;
	err = clGetDeviceIDs(plats[0], CL_DEVICE_TYPE_GPU, 0, 0, &numDevices);
	if (err != CL_SUCCESS)
		printf("error %d\n", err);
	assert(err == CL_SUCCESS);

	cl_device_id devices[numDevices];
	err = clGetDeviceIDs(plats[0], CL_DEVICE_TYPE_GPU, numDevices, devices, 0);
	if (err != CL_SUCCESS)
		printf("error %d\n", err);
	assert(err == CL_SUCCESS);
	int deviceUsed = 0;

#if defined (__APPLE__) || defined(MACOSX)
	CGLContextObj kCGLContext = CGLGetCurrentContext();
	CGLShareGroupObj kCGLShareGroup = CGLGetShareGroup(kCGLContext);

	cl_context_properties properties[] = {
		CL_CONTEXT_PROPERTY_USE_CGL_SHAREGROUP_APPLE,
		(cl_context_properties)kCGLShareGroup, 0
	};
#else
	cl_context_properties properties[] = {
		CL_GL_CONTEXT_KHR, (cl_context_properties)glXGetCurrentContext(), // GLX Context
		CL_GLX_DISPLAY_KHR, (cl_context_properties)glXGetCurrentDisplay(), // GLX Display
		CL_CONTEXT_PLATFORM, (cl_context_properties)plats[0], // OpenCL platform
		0
	};
#endif
	ctx->ctx = clCreateContext(properties, 1, &devices[deviceUsed], 0, 0, &err);	
	if (err != CL_SUCCESS)
		printf("error %d\n", err);
	assert(err == CL_SUCCESS);
	ctx->queue = clCreateCommandQueue(ctx->ctx, devices[deviceUsed], 0, &err);
	if (err != CL_SUCCESS)
		printf("error %d\n", err);
	assert(err == CL_SUCCESS);

	cl_program p[2];
	t_export_data file = get_embedded_data("build_cl_kernel_o");
	size_t len = *file.size;
	p[0] = clCreateProgramWithBinary(ctx->ctx, 1, &devices[deviceUsed], &len, &file.start, 0, &err);
	if (err != CL_SUCCESS)
		printf("error %d\n", err);
	assert(err == CL_SUCCESS);

	t_export_data file2 = get_embedded_data("build_cl_pok_o");
	size_t len2 = *file.size;
	p[1] = clCreateProgramWithBinary(ctx->ctx, 1, &devices[deviceUsed], &len2, &file2.start, 0, &err);
	if (err != CL_SUCCESS)
		printf("error %d\n", err);
	assert(err == CL_SUCCESS);

	ctx->program = clLinkProgram(ctx->ctx, 1, &devices[deviceUsed], 0, 2, p, 0, 0, &err);

	//err = clBuildProgram(ctx->program, 1, &devices[deviceUsed], 0, 0, 0);
	if (err != CL_SUCCESS)
		printf("error %d\n", err);
	if (err != CL_SUCCESS)
	{
		printf("error %d\n", err);
		char *b;
		clGetProgramBuildInfo(ctx->program, devices[deviceUsed], CL_PROGRAM_BUILD_LOG, 0, 0, &len);
		b = calloc(1, len);
		clGetProgramBuildInfo(ctx->program, devices[deviceUsed], CL_PROGRAM_BUILD_LOG, len, b, 0);
		puts(b);
		free(b);
	}
	assert(err == CL_SUCCESS);


	
	ctx->kernel = clCreateKernel(ctx->program, "clear_screen", &err);
	if (err != CL_SUCCESS)
		printf("error %d\n", err);
	assert(err == CL_SUCCESS);
	return 1;
}

void destroy_opencl(t_clctx *ctx)
{
	int err;
	err = clReleaseKernel(ctx->kernel);
	assert(err == CL_SUCCESS);
	err = clReleaseProgram(ctx->program);
	assert(err == CL_SUCCESS);
	err = clReleaseCommandQueue(ctx->queue);
	assert(err == CL_SUCCESS);
	err = clReleaseContext(ctx->ctx);
	assert(err == CL_SUCCESS);
}

#include <stdio.h>
#include <unistd.h>

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
	if (err != CL_SUCCESS)
		printf("error %d\n", err);
	assert(err == CL_SUCCESS);
	win->on_key = handle_key;
	xmlx_run_window(win, event_loop, &ctx);

	xmlx_destroy_window(win);
	xmlx_destroy();
	destroy_opencl(&ctx);
}
