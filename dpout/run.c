#include <u.h>
#include <libc.h>
#include <keyboard.h>

u8int *rr;
u32int *r;
u8int *rom;

enum {
	CMD = 0,
	PHY = 1,
	HVACT = 2,
	HVTOT = 3,
	HVSYNC = 4,
	HVSTART = 5,
	MISC0 = 6,
	MISC1 = 7,
	MISC2 = 8,
	DMASTART = 9,
	DMAEND = 10,
	TRACECTL = 32,
	KEYS = 33,
	TRACE0 = 32,
	TRACE1 = 33,
	TRACE2 = 34,
	XY = 35,
	PX = 36,
	BUF = 64,
	
	AUXREAD = 0x90,
	AUXWRITE = 0x80,
	
	/* PHY */
	PHYRESET = 1<<31,
	SRCACT = 1<<30,
	NESACT = 1<<29,
	PHYOFF = 0,
	PHYACT = 1,
	PHYTR1 = 2,
	PHYTR2 = 3,
	
	/* TRACECTL */
	SINGLESTEP = 1,
	STEP = 2,
	STEPWAIT = 4,
	PIXELSTEP = 8,
};

u8int
dpread(u32int reg)
{
	rr[BUF] = AUXREAD | reg >> 16 & 0xf;
	rr[BUF+1] = reg >> 8;
	rr[BUF+2] = reg;
	rr[BUF+3] = 1;
	r[CMD] = 4;
	sleep(1);
	if(r[CMD] >> 16 != 4)
		sysfatal("invalid bytes received");
	if(rr[BUF] != 0)
		sysfatal("NAK");
	return rr[BUF+1];
}

void
dpwrite(u32int reg, int n, ...)
{
	int i;
	va_list va;

	rr[BUF] = AUXWRITE | reg >> 16 & 0xf;
	rr[BUF+1] = reg >> 8;
	rr[BUF+2] = reg;
	rr[BUF+3] = n;
	va_start(va, n);
	for(i = 0; i < n; i++)
		rr[BUF+4+i] = va_arg(va, int);
	r[CMD] = 4+n;
	sleep(1);
	if(r[CMD] >> 16 != 4)
		sysfatal("invalid bytes received");
	if(rr[BUF] != 0)
		sysfatal("NAK");
}

void
romread(char *file)
{
	int fd, len;
	void *v;
	
	v = segattach(0, "membuf", nil, 1048576);
	if(v == (void*)-1)
		sysfatal("segattach: %r");
	fd = open(file, OREAD);
	if(fd < 0)
		sysfatal("open: %r");
	len = seek(fd, 0, 2);
	seek(fd, 0, 0);
	if(readn(fd, v, len) < len)
		sysfatal("readn: %r");
}

void
trace(void)
{
	ulong a, b, c, t;
	ushort pc;
	int tr;

	r[TRACECTL] = SINGLESTEP;
	tr=0;
	for(;;){
		r[TRACECTL] = STEP|SINGLESTEP|STEPWAIT;
		a = r[TRACE0];
		b = r[TRACE1];
		c = r[TRACE2];
		pc = b;
		t = c >> 27;
	//	if(pc == 0xf4ae)
	//	if((u16int)r[XY] <= 2)
			print("%.4ux %ux %c %.4x %.2x | %.2x %.2x %.2x | %.2x %.2x %c%c %d %d\n", pc, c >> 27, c & 1<<26 ? 'W' : 'R', b >> 16, c & 0xff, c >> 8 & 0xff, a >> 24 & 0xff, a >> 16 & 0xff, a >> 8 & 0xff, a & 0xff, c & 1<<24 ? 'N':' ', c & 1<<25 ? 'I':' ', r[XY] & 0xffff, r[XY] >> 16);
	}
}

void
pxtrace(void)
{
	for(;;){
		r[TRACECTL] = PIXELSTEP|STEP|STEPWAIT;
		print("%x %x\n", r[XY], r[PX]);
	}
}

void
keys(void)
{
	int fd, k;
	static char buf[256];
	char *s;
	Rune ru;

	fd = open("/dev/kbd", OREAD);
	if(fd < 0)
		sysfatal("open: %r");
	for(;;){
		if(read(fd, buf, sizeof(buf) - 1) <= 0)
			sysfatal("read /dev/kbd: %r");
		if(buf[0] == 'c'){
			if(utfrune(buf, Kdel)){
				close(fd);
				exits(nil);
			}
			if(utfrune(buf, 't')){
				close(fd);
				trace();
			}
		}
		if(buf[0] != 'k' && buf[0] != 'K')
			continue;
		s = buf + 1;
		k = 0;
		while(*s != 0){
			s += chartorune(&ru, s);
			switch(ru){
			case Kdel: close(fd); exits(nil);
			case 'x': k |= 1<<7; break;
			case 'z': k |= 1<<6; break;
			case Kshift: k |= 1<<5; break;
			case 10: k |= 1<<4; break;
			case Kup: k |= 1<<3; break;
			case Kdown: k |= 1<<2; break;
			case Kleft: k |= 1<<1; break;
			case Kright: k |= 1<<0; break;
			}
		}
		r[KEYS] = k;
	}

}

void
main(int argc, char **argv)
{
	ulong v;

	if(argc != 2)
		sysfatal("usage: %s rom", argv[1]);
	r = segattach(0, "axi", 0, 4096);
	if(r == (void*)-1)
		sysfatal("segattach: %r");
	rr = (u8int*)r;

	r[PHY] = PHYRESET;
	r[PHY] = PHYTR1;
	dpwrite(0x100, 8, 0x06, 1, 0x21, 0x00, 0x00, 0x00, 0x00, 0);
	sleep(100);
	if((dpread(0x202) & 1) == 0)
		sysfatal("clock recovery failed");
	r[PHY] = PHYTR2;
	dpwrite(0x102, 1, 0x22);
	sleep(100);
	if((dpread(0x202) & 1) == 0)
		sysfatal("clock lost");
	if((dpread(0x202) & 2) == 0)
		sysfatal("channel eq failed");
	if((dpread(0x202) & 4) == 0)
		sysfatal("symbol alignment failed");

	r[HVACT] = 640 << 16 | 480;
	r[HVTOT] = 800 << 16 | 525;
	r[HVSYNC] = 96 << 16 | 2 | 0x80008000;
	r[HVSTART] = 144 << 16 | 35;
	r[MISC0] = 42 << 16 | 0x0021;
	r[MISC1] = 275 << 8;
	r[MISC2] = 0x4e32;
	
	r[DMASTART] = 0x920000;
	r[DMAEND] = 0x920000 + 1048576;
	
	romread(argv[1]);
	
	r[PHY] = PHYACT | SRCACT | NESACT;
	r[TRACECTL] = 0;
	sleep(10);
	dpwrite(0x102, 1, 0);

	keys();
	//trace();
}
