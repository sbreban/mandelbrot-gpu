#include "util.h"

unsigned char color2byte(float v) {
    float c = v * 255;
    if (c < 0) {
        c = 0;
    }
    if (c > 255) {
        c = 255;
    }
    return (unsigned char)c;
}

void hsv2rgb(float h, float s, float v, unsigned char* rgb) {
    int i;
    float f, p, q, t, r, g, b;

    if (s == 0) {
        r = g = b = v;
        return;
    }

    h /= 60;
    i = (int)floor(h);
    f = h - i;
    p = v * (1 - s);
    q = v * (1 - s * f);
    t = v * (1 - s * (1 - f));

    switch (i) {
    case 0:
        r = v;
        g = t;
        b = p;
        break;
    case 1:
        r = q;
        g = v;
        b = p;
        break;
    case 2:
        r = p;
        g = v;
        b = t;
        break;
    case 3:
        r = p;
        g = q;
        b = v;
        break;
    case 4:
        r = t;
        g = p;
        b = v;
        break;
    default:
        r = v;
        g = p;
        b = q;
        break;
    }

    rgb[0] = color2byte(r);
    rgb[1] = color2byte(g);
    rgb[2] = color2byte(b);
}

void init_colormap(int len, unsigned char* map) {
    int i;
    for (i = 0; i < len; i++) {
        hsv2rgb(i / 4.0f, 1.0f, i / (i + 8.0f), &map[i * 3]);
    }
    map[3 * len + 0] = 0;
    map[3 * len + 1] = 0;
    map[3 * len + 2] = 0;

}

void set_pixel(unsigned char* image, int width, int x, int y, unsigned char *c) {
    image[4 * width * y + 4 * x + 0] = c[0];
    image[4 * width * y + 4 * x + 1] = c[1];
    image[4 * width * y + 4 * x + 2] = c[2];
    image[4 * width * y + 4 * x + 3] = 255;
}

void save_image(const char* filename, const unsigned char* image, unsigned width, unsigned height) {
    unsigned error;
    unsigned char* png;
    size_t pngsize;
    LodePNGState state;

    lodepng_state_init(&state);

    error = lodepng_encode(&png, &pngsize, image, width, height, &state);
    if (!error) {
        lodepng_save_file(png, pngsize, filename);
    }
    if (error) {
        fprintf(stderr, "ERROR: %u: %s\n", error, lodepng_error_text(error));
    }
    lodepng_state_cleanup(&state);
    free(png);
}

void description(char* name, char* desc) {
    if(strcmp("gpu", name) == 0) {
		sprintf(desc, "width=%d height=%d iterations=%d grid size=%dx%d block size=%dx%d pixels per kernel=%d -- colormap in global memory", WIDTH, HEIGHT, MAX_ITERATION, GRID_SIZE_X, GRID_SIZE_Y, BLOCK_SIZE_X, BLOCK_SIZE_Y, PIXELS);
	} else {
        sprintf(desc, "-");
    }
}

void progress(char* name, int r, double time) {
    char desc[200];
    description(name, desc);
    fprintf(stderr, "name=%s %s repeat=%d/%d duration=%.2lf\n", name, desc, r+1, REPEAT, time);
}

void report(char* name, double* times) {
    int r;
    double avg, stdev, min, max, mean;
    char desc[200], rep[1000];
    FILE* f;

    description(name, desc);

    avg = 0;
    min = times[0];
    max = times[0];
    for (r = 0; r < REPEAT; r++) {
        avg += times[r];
        if (min > times[r]) {
            min = times[r];
        }
        if (max < times[r]) {
            max = times[r];
        }
    }
    avg /= REPEAT;

    stdev = 0;
    for (r = 0; r < REPEAT; r++) {
        stdev += (times[r] - avg)*(times[r] - avg);
    }
    stdev = sqrt(stdev / REPEAT);

    mean = times[REPEAT / 2];

    sprintf(rep, "name=%s %s min=%.2lf max=%.2lf mean=%.2lf avg=%.2lf stdev=%.2lf\n", name, desc, min, max, mean, avg, stdev);

    f = fopen(REPORT, "a");
    fprintf(f, rep);
    fclose(f);
    fprintf(stderr, rep);
}
