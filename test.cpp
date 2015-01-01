#include "Vnes.h"
#include "verilated.h"
#if VM_TRACE
#include "verilated_vcd_c.h"
#endif
#include <stdio.h>
#include <stdlib.h>
#include <SDL.h>

uint8_t *rom;
SDL_Surface *screen;

enum {
	SYM0 = SDLK_RIGHT,
	SYM1 = SDLK_LEFT,
	SYM2 = SDLK_DOWN,
	SYM3 = SDLK_UP,
	SYM4 = SDLK_RETURN,
	SYM5 = SDLK_TAB,
	SYM6 = 'b',
	SYM7 = 'a',
};

Vnes *top;

vluint64_t main_time = 0;

double
sc_time_stamp()
{
	return main_time;
}

int
main(int argc, char **argv)
{
	FILE *f;
	int sz;
	SDL_Event ev;
	uint8_t k;

	if(SDL_Init(SDL_INIT_VIDEO) < 0){
	error:
		fprintf(stderr, "Error: %s\n", SDL_GetError());
		return 1;
	}
	screen = SDL_SetVideoMode(640, 480, 32, 0);
	if(screen == NULL)
		goto error;
	f = fopen("smb.nes", "rb");
	fseek(f, 0, SEEK_END);
	sz = ftell(f);
	fseek(f, 0, SEEK_SET);
	rom = (uint8_t *) malloc(sz);
	fread(rom, sz, 1, f);
	fclose(f);

	Verilated::commandArgs(argc, argv);
	top = new Vnes;
#if VM_TRACE
	Verilated::traceEverOn(true);
	VerilatedVcdC* tfp = new VerilatedVcdC;
	top->trace(tfp, 99);
	tfp->open("obj_dir/sim.vcd");
#endif
	top->init = 1;
	top->romack = 0;
	while(!Verilated::gotFinish()){
		if((main_time % 100000) == 0)
			while(SDL_PollEvent(&ev))
				switch(ev.type){
				case SDL_KEYDOWN:
					switch(ev.key.keysym.sym){
					case SYM0: k |= 1; break;
					case SYM1: k |= 2; break;
					case SYM2: k |= 4; break;
					case SYM3: k |= 8; break;
					case SYM4: k |= 16; break;
					case SYM5: k |= 32; break;
					case SYM6: k |= 64; break;
					case SYM7: k |= 128; break;
					}
					break;
				case SDL_KEYUP:
					switch(ev.key.keysym.sym){
					case SYM0: k &= ~1; break;
					case SYM1: k &= ~2; break;
					case SYM2: k &= ~4; break;
					case SYM3: k &= ~8; break;
					case SYM4: k &= ~16; break;
					case SYM5: k &= ~32; break;
					case SYM6: k &= ~64; break;
					case SYM7: k &= ~128; break;
					}
					break;
				case SDL_QUIT:
					SDL_Quit();
					return 0;
				}
		if(main_time > 10)
			top->init = 0;
		if((main_time % 10) == 1)
			top->clk = 1;
		if((main_time % 10) == 6){
			top->clk = 0;
			top->input0 = k;
			if(top->romreq){
				top->romdata = rom[top->romaddr];
				top->romack = 1;
			}else
				top->romack = 0;
			if(top->pxvalid){
				if(top->outx == 0)
					SDL_UpdateRect(screen, 0, top->outy - 1, 640, top->outy);
				((uint32_t *)screen->pixels)[top->outy * 640 + top->outx] = top->pix;
				
			}
		}
		top->eval();
		main_time++;
#if VM_TRACE
		tfp->dump(main_time);
#endif
	}
#if VM_TRACE
	tfp->close();
#endif
	delete top;
	exit(0);
}
