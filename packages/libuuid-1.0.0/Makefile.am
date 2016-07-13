# Makefile.am by hightman
# for libuuid-simple
ATOMAKE_OPTIONS = foreign

sysconf_DATA = 

bin_PROGRAMS = tst_uuid uuid_time

tst_uuid_SOURCES = tst_uuid.c
tst_uuid_LDADD = libuuid.la

uuid_time_SOURCES = uuid_time2.c
uuid_time_LDADD = libuuid.la

includedir = @prefix@/include/uuid
include_HEADERS = uuid.h
noinst_HEADERS = uuidP.h uuidd.h

lib_LTLIBRARIES = libuuid.la

libuuid_la_SOURCES  = clear.c compare.c copy.c gen_uuid.c isnull.c
libuuid_la_SOURCES += pack.c parse.c unpack.c unparse.c uuid_time.c
libuuid_la_LDFLAGS = @LDFLAGS@ -no-undefined -version-info @SHARED_LIB_VERSION@


man3_MANS  = uuid.3 uuid_clear.3 uuid_compare.3 uuid_copy.3
man3_MANS += uuid_generate.3 uuid_is_null.3 uuid_parse.3
man3_MANS += uuid_time.3 uuid_unparse.3

pkgconfigdir = @prefix@/lib/pkgconfig
pkgconfig_DATA = uuid.pc

EXTRA_DIST = *.in

SUFFIXES = .3.in .3

.3.in.3:
	CONFIG_FILES=$@ ./config.status

uuid.pc: uuid.pc.in config.status
	CONFIG_FILES=$@ ./config.status

check: tst_uuid$(EXEEXT)
	./tst_uuid$(EXEEXT)

clean-generic:
	rm -f $(pkgconfig_DATA)

dist-hook: clean-generic


