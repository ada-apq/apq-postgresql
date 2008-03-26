# Makefile for the AW_Lib
#
# @author Marcelo Coraça de Freitas <marcelo.batera@gmail.com> 


projectFile="apq-postgresql.gpr"


libs: c_libs
	gnatmake -P ${projectFile}



c_libs: c_objs
	cd lib && gcc -shared ../obj-c/{numeric,notices}.o -o libapq-postgresqlhelp.so -lpq

c_objs:
	cd obj-c && gcc -fPIC -I../src-c ../src-c/numeric.c -c -o numeric.o && gcc -fPIC -I../src-c ../src-c/notices.c -c -o notices.o

all: libs


clean:
	gnatclean -P ${projectFile}
	@rm -f obj-c/* lib/*
	@echo "All clean"

docs:
	@-./gendoc.sh
	@echo "The documentation is generated by a bash script. Then it might fail in other platforms"
