set-variable program_name "tdgbd"

rgbasm src/main.s -o bin/main.o -Wall
rgblink -o bin/${program_name}.gb --map bin/${program_name}.map bin/main.o
rgbfix -v bin/${program_name}.gb -p 0xff

& "./bin/$program_name.gb"