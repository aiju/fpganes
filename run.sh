if [ z"$1" = z--trace ]; then
	a="--trace"
else
	a=""
fi
verilator $a --cc -Wno-CASEINCOMPLETE -CFLAGS "`sdl-config --cflags`" -LDFLAGS "`sdl-config --libs`" -Wno-UNOPTFLAT nes.v --exe test.cpp && (cd obj_dir; make -f Vnes.mk Vnes) && obj_dir/Vnes || exit 0
/gtkwave/bin/vcd2fst obj_dir/sim.vcd obj_dir/sim.fst
