build: assets
	c3c compile -D PLATFORM_WEB --reloc=none --trust=full --target wasm32 -O5 -g0 --link-libc=no --no-entry -z --export-table -z --allow-undefined -o main main.c3 assets.c3
assets: stb_image stb_image_resize
	c3c compile packer.c3 assets.c3 stb_image.o stb_image_resize2.o
stb_image:
	clang -DSTB_IMAGE_IMPLEMENTATION -x c -c stb_image.h
stb_image_resize:
	clang -DSTB_IMAGE_RESIZE_IMPLEMENTATION -x c -c stb_image_resize2.h