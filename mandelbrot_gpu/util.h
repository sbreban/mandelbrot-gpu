#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <sys/timeb.h>

#include "lodepng.h"
#include "config.h"

#ifndef _UTIL_H
#define _UTIL_H

struct arg {
    unsigned char* image;
    unsigned char* colormap;
    int width;
    int height;
    int max;
    int id;
    int threads;
};

unsigned char color2byte(float v);

void hsv2rgb(float h, float s, float v, unsigned char* rgb);

void init_colormap(int len, unsigned char* map);

void set_pixel(unsigned char* image, int width, int x, int y, unsigned char *c);

void save_image(const char* filename, const unsigned char* image, unsigned width, unsigned height);

void description(char* name, char* desc);

void progress(char* name, int r, double time);

void report(char* name, double* times);

#endif
