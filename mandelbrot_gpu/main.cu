#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include "util.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <sys/timeb.h>

using namespace std;

#define cudaAssertSuccess(ans) { _cudaAssertSuccess((ans), __FILE__, __LINE__); }

__device__ __constant__ unsigned char d_const_colormap[(MAX_ITERATION + 1) * 3 * sizeof(unsigned char)];

__global__ void generate_image(unsigned char *d_image, unsigned char *d_colormap);

inline void _cudaAssertSuccess(cudaError_t code, char *file, int line) {
	if(code != cudaSuccess) {
		fprintf(stderr, "_cudaAssertSuccess: %s %s %d\n", cudaGetErrorString(code), file, line);
		exit(code);
	}
}

__global__ void generate_image(unsigned char *d_image, unsigned char *d_colormap) {
	double c_re, c_im, x, y, x_new;
	int row, col, idx, iteration;

	int width = WIDTH;
	int height = HEIGHT;
	int max = MAX_ITERATION;

	int blockId = blockIdx.x + blockIdx.y * gridDim.x;
	idx = blockId * (blockDim.x * blockDim.y) + (threadIdx.y * blockDim.x) + threadIdx.x;

	if (idx >= width * height) return;

	for (int i = 0; i < PIXELS; i++) {
		int new_idx = PIXELS * idx + i;
		row = new_idx / WIDTH;
		col = new_idx % WIDTH;

		c_re = (col - width / 2.0)*4.0 / width;
		c_im = (row - height / 2.0)*4.0 / width;
		x = 0, y = 0;
		iteration = 0;
		while (x*x + y*y <= 4 && iteration < max) {
			x_new = x*x - y*y + c_re;
			y = 2 * x*y + c_im;
			x = x_new;
			iteration++;
		}
		if (iteration > max) {
			iteration = max;
		}
		d_image[4 * new_idx + 0] = d_colormap[iteration * 3 + 0];
		d_image[4 * new_idx + 1] = d_colormap[iteration * 3 + 1];
		d_image[4 * new_idx + 2] = d_colormap[iteration * 3 + 2];
		d_image[4 * new_idx + 3] = 255;
	}
}

__global__ void generate_image(unsigned char *d_image) {
	double c_re, c_im, x, y, x_new;
	int row, col, idx, iteration;

	int width = WIDTH;
	int height = HEIGHT;
	int max = MAX_ITERATION;

	int blockId = blockIdx.x + blockIdx.y * gridDim.x;
	idx = blockId * (blockDim.x * blockDim.y) + (threadIdx.y * blockDim.x) + threadIdx.x;

	if(idx >= width * height) return;

	for(int i = 0; i < PIXELS; i++) {
		int new_idx = PIXELS * idx + i;
		row = new_idx / WIDTH;
		col = new_idx % WIDTH;

		c_re = (col - width / 2.0)*4.0 / width;
		c_im = (row - height / 2.0)*4.0 / width;
		x = 0, y = 0;
		iteration = 0;
		while(x*x + y*y <= 4 && iteration < max) {
			x_new = x*x - y*y + c_re;
			y = 2 * x*y + c_im;
			x = x_new;
			iteration++;
		}
		if(iteration > max) {
			iteration = max;
		}
		d_image[4 * new_idx + 0] = d_const_colormap[iteration * 3 + 0];
		d_image[4 * new_idx + 1] = d_const_colormap[iteration * 3 + 1];
		d_image[4 * new_idx + 2] = d_const_colormap[iteration * 3 + 2];
		d_image[4 * new_idx + 3] = 255;
	}
}

void fractals(unsigned char *image, unsigned char *colormap, double *times) {
	unsigned char *d_image, *d_colormap;
	struct timeb start[REPEAT], end[REPEAT], before_data_send, after_data_send;
	char path[255];
	double data_send_time;
	dim3 grid(GRID_SIZE_X, GRID_SIZE_Y);
	dim3 block(BLOCK_SIZE_X, BLOCK_SIZE_Y);
	cudaError_t cudaStatus;
	ftime(&before_data_send);

	cudaStatus = cudaSetDevice(0);
	if(cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
		goto Error_No_Free;
	}

	cudaStatus = cudaMalloc(&d_image, WIDTH * HEIGHT * 4 * sizeof(unsigned char));
	if(cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error_No_Free;
	}

	if (USE_GLOBAL_MEMORY == 0) {
		cudaStatus = cudaMalloc(&d_colormap, (MAX_ITERATION + 1) * 3 * sizeof(unsigned char));
		if (cudaStatus != cudaSuccess) {
			fprintf(stderr, "cudaMalloc failed!");
			goto Error_Free_Image;
		}

		cudaStatus = cudaMemcpy(d_colormap, colormap, (MAX_ITERATION + 1) * 3 * sizeof(unsigned char), cudaMemcpyHostToDevice);
		if (cudaStatus != cudaSuccess) {
			fprintf(stderr, "cudaMemcpy failed!");
			goto Error;
		}
	} else {
		cudaStatus = cudaMemcpyToSymbol(d_const_colormap, colormap, (MAX_ITERATION + 1) * 3 * sizeof(unsigned char));
		if (cudaStatus != cudaSuccess) {
			fprintf(stderr, "cudaMemcpy failed!");
			goto Error;
		}
	}

	memset(image, 0, WIDTH * HEIGHT * 4 * sizeof(unsigned char));
	cudaMemcpy(d_image, image, WIDTH * HEIGHT * 4 * sizeof(unsigned char), cudaMemcpyHostToDevice);
	if(cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error;
	}

	ftime(&after_data_send);

	data_send_time = after_data_send.time - before_data_send.time + ((double)after_data_send.millitm - (double)before_data_send.millitm) / 1000.0;
	
	for(int i = 0; i < REPEAT; i++) {

		ftime(&start[i]);

		if (USE_GLOBAL_MEMORY == 0) {
			generate_image <<<grid, block >>> (d_image, d_colormap);
		}
		else {
			generate_image <<<grid, block >>> (d_image);
		}

		cudaStatus = cudaGetLastError();
		if(cudaStatus != cudaSuccess) {
			fprintf(stderr, "fractal launch failed: %s\n", cudaGetErrorString(cudaStatus));
			goto Error;
		}

		cudaStatus = cudaDeviceSynchronize();
		if(cudaStatus != cudaSuccess) {
			fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching addKernel!\n", cudaStatus);
			goto Error;
		}

		cudaStatus = cudaMemcpy(image, d_image, WIDTH * HEIGHT * 4 * sizeof(unsigned char), cudaMemcpyDeviceToHost);
		if(cudaStatus != cudaSuccess) {
			fprintf(stderr, "cudaMemcpy failed!");
			goto Error;
		}

		ftime(&end[i]);
		times[i] = data_send_time + end[i].time - start[i].time + ((double)end[i].millitm - (double)start[i].millitm) / 1000.0;

		sprintf(path, IMAGE, "gpu", i);
		save_image(path, image, WIDTH, HEIGHT);
		progress("gpu", i, times[i]);
	}
	Error:
		if (USE_GLOBAL_MEMORY == 0) {
			cudaFree(d_colormap);
		}
	Error_Free_Image:
	cudaFree(d_image);
	Error_No_Free:
}


int main(int argc, char** argv) {
	struct arg a;
	double *times = (double*)malloc(sizeof(double)*REPEAT);

	unsigned char *colormap = (unsigned char*)malloc((MAX_ITERATION + 1) * 3);
	unsigned char *image = (unsigned char*)malloc(WIDTH * HEIGHT * 4);
	init_colormap(MAX_ITERATION, colormap);
	
	fractals(image, colormap, times);
	getchar();
	report("gpu", times);

	free(image);
	free(colormap);
	
	return 0;
}