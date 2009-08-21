# Makefile for the AW_Lib
#
# @author Marcelo Coraça de Freitas <marcelo.batera@gmail.com> 


ifndef ($(PREFIX))
	PREFIX=/usr/local
endif

INCLUDE_PREFIX=$(PREFIX)/include
LIB_PREFIX=$(PREFIX)/lib
GPR_PREFIX=$(LIB_PREFIX)/gnat


#POSTGRESQL_PATH=/c/Program Files/PostgreSQL/8.3/
#POSTGRESQL_INCLUDE=${POSTGRESQL_PATH}/include
#POSTGRESQL_LIB=${POSTGRESQL_PATH}/lib



POSTGRESQL_PATH=/c/postgresql/
POSTGRESQL_INCLUDE=${POSTGRESQL_PATH}/include
POSTGRESQL_LIB=${POSTGRESQL_PATH}/lib

#OUTPUT_NAME is the name of the compiled library.
ifeq ($(OS), Windows_NT)
	OUTPUT_NAME=apq-postgresqlhelp.dll
else
	OUTPUT_NAME=libapq-postgresqlhelp.so
endif



all: libs gprfile

projectFile="apq-postgresql.gpr"


libs: c_libs
	gnatmake -P ${projectFile} -L"${POSTGRESQL_LIB}" -lpq



c_libs: c_objs
	cd lib && gcc -shared ../obj-c/numeric.o ../obj-c/notices.o -o $(OUTPUT_NAME) -L"${POSTGRESQL_LIB}" -lpq

c_objs:
	cd obj-c && gcc -fPIC -I/usr/include/postgresql/ -I../src-c ../src-c/numeric.c -c -o numeric.o && gcc -fPIC -I"${POSTGRESQL_INCLUDE}" -I../src-c ../src-c/notices.c -c -o notices.o



clean: gprclean
	gnatclean -P ${projectFile}
	@rm -f obj-c/* lib/*
	@echo "All clean"

docs:
	@-./gendoc.sh
	@echo "The documentation is generated by a bash script. Then it might fail in other platforms"



gprfile:
	@echo "Preparing GPR file.."
	@echo prefix:=\"$(PREFIX)\" >> gpr/apq-postgresql.def
	@gnatprep gpr/apq-postgresql.gpr.in gpr/apq-postgresql.gpr gpr/apq-postgresql.def

gprclean:
	@rm -f gpr/apq-postgresql.gpr gpr/apq-postgresql.def

install:
	@echo "Installing files"
	install -d $(INCLUDE_PREFIX)
	install -d $(LIB_PREFIX)
	install -d $(GPR_PREFIX)
	install src*/* -t $(INCLUDE_PREFIX)
	install lib/* -t $(LIB_PREFIX)
	install gpr/*.gpr -t $(GPR_PREFIX)
