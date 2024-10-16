build:
	c3c compile -D PLATFORM_WEB --reloc=none --target wasm32 -O5 -g0 --link-libc=no --no-entry -z --export-table -z --allow-undefined -o main main.c3