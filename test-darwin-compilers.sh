#!/bin/bash

# Attempts to compile and link ndk-stack under various conditions with various compilers.

. bash-tools.sh

UNAME=$(uname-bt)
if [[ "$UNAME" = "Linux" ]] ; then
	STRACE="strace -F -s 512 -e access,open,execve,stat64,fstat64"
	COMPARE=bcmp
elif [[ "$UNAME" = "Darwin" ]] ; then
	STRACE="dtruss -f -L"
	COMPARE=compare
fi

download http://dl.google.com/android/ndk/android-ndk-r6b-linux-x86.tar.bz2
if [[ ! -d android-ndk-r6b ]] ; then
	tar -xjf android-ndk-r6b-linux-x86.tar.bz2
	pushd android-ndk-r6b
	patch -p1 < ../patches/test/android-ndk-r6b-darwincross.patch
	popd
fi

OUTDIR=$PWD

if [[ ! -z $1 ]] ; then
	LEFT=${1}
else
	error "Please specify the left hand toolchain"
	exit 1
fi
PREFIXLEFT=$LEFT

if [[ ! -z $2 ]] ; then
	RIGHT=${2}
	OUTRIGHT=$OUTDIR/$RIGHT
	mkdir -p $OUTRIGHT
else
	RIGHT=/
	OUTRIGHT=$OUTDIR/apple
	mkdir -p $OUTRIGHT
fi

TOOLCHAINLEFT=/tmp2/$LEFT/bin/${LEFT}-g++
if [[ "$RIGHT" = "/" ]] ; then
	TOOLCHAINRIGHT=/usr/bin/llvm-g++-4.2
	PREFIXRIGHT=apple
else
	TOOLCHAINRIGHT=/tmp2/$RIGHT/bin/${RIGHT}-g++
	PREFIXRIGHT=$RIGHT
fi

TOOLCHAIN1=$TOOLCHAINLEFT
TOOLCHAIN2=$TOOLCHAINLEFT
TOOLCHAIN3=$TOOLCHAINRIGHT
TOOLCHAIN4=$TOOLCHAINRIGHT
OUT1=$OUTDIR/${UNAME}-${PREFIXLEFT}-1
OUT2=$OUTDIR/${UNAME}-${PREFIXLEFT}-2
OUT3=$OUTDIR/${UNAME}-${PREFIXRIGHT}-3
OUT4=$OUTDIR/${UNAME}-${PREFIXRIGHT}-4

rm -rf $OUT1 $OUT2 $OUT3 $OUT4
mkdir -p $OUT1
mkdir -p $OUT2
mkdir -p $OUT3
mkdir -p $OUT4

#ARCHS="-arch x86_64 -arch i386"
ARCHS="-arch x86_64"

SDK=$PWD/sdks/MacOSX10.7.sdk

pushd android-ndk-r6b/sources/host-tools/ndk-stack
SRCDIR=$PWD
popd

SRCS="$SRCDIR/ndk-stack.c $SRCDIR/ndk-stack-parser.c $SRCDIR/elff/dwarf_cu.cc $SRCDIR/elff/dwarf_die.cc $SRCDIR/elff/dwarf_utils.cc $SRCDIR/elff/elf_alloc.cc $SRCDIR/elff/elf_file.cc $SRCDIR/elff/elf_mapped_section.cc $SRCDIR/elff/elff_api.cc $SRCDIR/elff/mapfile.c $SRCDIR/regex/regcomp.c $SRCDIR/regex/regerror.c $SRCDIR/regex/regexec.c $SRCDIR/regex/regfree.c"
# ndk-stack.c ndk-stack-parser.c elff/dwarf_cu.cc elff/dwarf_die.cc elff/dwarf_utils.cc elff/elf_alloc.cc elff/elf_file.cc elff/elf_mapped_section.cc elff/elff_api.cc elff/mapfile.c regex/regcomp.c regex/regerror.c regex/regexec.c regex/regfree.c 

pushd $OUT1
echo     "${TOOLCHAIN1} $ARCHS -lstdc++ $SRCS -o $OUT1/ndk-stack --sysroot $SDK"    > strace.txt 2>&1
echo     "${TOOLCHAIN1} $ARCHS -lstdc++ $SRCS -o $OUT1/ndk-stack --sysroot $SDK -v" > output.txt 2>&1
${STRACE} ${TOOLCHAIN1} $ARCHS -lstdc++ $SRCS -o $OUT1/ndk-stack --sysroot $SDK    >> strace.txt 2>&1
          ${TOOLCHAIN1} $ARCHS -lstdc++ $SRCS -o $OUT1/ndk-stack --sysroot $SDK -v --save-temps >> output.txt 2>&1
popd

pushd $OUT2
echo     "${TOOLCHAIN2} $ARCHS -lstdc++ $SRCS -o $OUT2/ndk-stack --sysroot /   "    > strace.txt 2>&1
echo     "${TOOLCHAIN2} $ARCHS -lstdc++ $SRCS -o $OUT2/ndk-stack --sysroot /   -v"  > output.txt 2>&1
${STRACE} ${TOOLCHAIN2} $ARCHS -lstdc++ $SRCS -o $OUT2/ndk-stack --sysroot /       >> strace.txt 2>&1
          ${TOOLCHAIN2} $ARCHS -lstdc++ $SRCS -o $OUT2/ndk-stack --sysroot /   -v --save-temps  >> output.txt 2>&1
popd

pushd $OUT3
echo     "${TOOLCHAIN3} $ARCHS -lstdc++ $SRCS -o $OUT3/ndk-stack               "    > strace.txt 2>&1
echo     "${TOOLCHAIN3} $ARCHS -lstdc++ $SRCS -o $OUT3/ndk-stack               -v"  > output.txt 2>&1
${STRACE} ${TOOLCHAIN3} $ARCHS -lstdc++ $SRCS -o $OUT3/ndk-stack                   >> strace.txt 2>&1
          ${TOOLCHAIN3} $ARCHS -lstdc++ $SRCS -o $OUT3/ndk-stack               -v --save-temps  >> output.txt 2>&1
popd

pushd $OUT4
echo     "${TOOLCHAIN4} $ARCHS -lstdc++ $SRCS -o $OUT4/ndk-stack --sysroot $SDK"    > strace.txt 2>&1
echo     "${TOOLCHAIN4} $ARCHS -lstdc++ $SRCS -o $OUT4/ndk-stack --sysroot $SDK -v" > output.txt 2>&1
${STRACE} ${TOOLCHAIN4} $ARCHS -lstdc++ $SRCS -o $OUT4/ndk-stack --sysroot $SDK    >> strace.txt 2>&1
          ${TOOLCHAIN4} $ARCHS -lstdc++ $SRCS -o $OUT4/ndk-stack --sysroot $SDK -v --save-temps >> output.txt 2>&1
popd

${TOOLCHAIN1} -dumpspecs > $OUT1/specs.txt 2>&1
${TOOLCHAIN2} -dumpspecs > $OUT2/specs.txt 2>&1
${TOOLCHAIN3} -dumpspecs > $OUT3/specs.txt 2>&1
${TOOLCHAIN4} -dumpspecs > $OUT4/specs.txt 2>&1

rm -f $(uname-bt)-test.7z
rm -f ~/Dropbox/darwin-compilers-work/$(uname-bt)-test.7z
7za a -mx=9 ${UNAME}-test.7z $OUT1 $OUT2 $OUT3 $OUT4
cp ${UNAME}-test.7z ~/Dropbox/darwin-compilers-work/

if [[ $(which $COMPARE) ]] ; then
	$COMPARE $OUT3/strace.txt $OUT4/strace.txt &
	$COMPARE $OUT3/output.txt $OUT4/output.txt &
#	$COMPARE $OUTLEFT/search-dirs.txt $OUTMIDDLE/search-dirs.txt &
#	$COMPARE $OUTLEFT/specs.txt $OUTMIDDLE/specs.txt &
#	$COMPARE $OUTLEFT/print-prog-name-as.txt $OUTMIDDLE/print-prog-name-as.txt &
fi

# Works (3):
# ${TOOLCHAIN3} $ARCHS -lstdc++ ndk-stack.c ndk-stack-parser.c elff/dwarf_cu.cc elff/dwarf_die.cc elff/dwarf_utils.cc elff/elf_alloc.cc elff/elf_file.cc elff/elf_mapped_section.cc elff/elff_api.cc elff/mapfile.c regex/regcomp.c regex/regerror.c regex/regexec.c regex/regfree.c -o $OUT3/ndk-stack               -v  >> $OUT3/output.txt 2>&1
#  /usr/llvm-gcc-4.2/bin/../libexec/gcc/i686-apple-darwin11/4.2.1/collect2 -dynamic -arch x86_64 -macosx_version_min 10.7.0 -weak_reference_mismatches non-weak -o /Volumes/Work/toolchain4/Darwin-apple-3/ndk-stack -lcrt1.10.6.o -L/usr/llvm-gcc-4.2/bin/../lib/gcc/i686-apple-darwin11/4.2.1/x86_64 -L/Developer/usr/llvm-gcc-4.2/lib/gcc/i686-apple-darwin11/4.2.1/x86_64 -L/usr/llvm-gcc-4.2/bin/../lib/gcc/i686-apple-darwin11/4.2.1 -L/usr/llvm-gcc-4.2/bin/../lib/gcc -L/Developer/usr/llvm-gcc-4.2/lib/gcc/i686-apple-darwin11/4.2.1 -L/usr/llvm-gcc-4.2/bin/../lib/gcc/i686-apple-darwin11/4.2.1/../../.. -L/Developer/usr/llvm-gcc-4.2/lib/gcc/i686-apple-darwin11/4.2.1/../../..                                                                                                                                                                                     -lstdc++ /var/tmp//ccDvKtne.o /var/tmp//cc0tc0KB.o /var/tmp//ccNIencd.o /var/tmp//cc7lXLm5.o /var/tmp//ccB26SYH.o /var/tmp//ccLzXB7q.o /var/tmp//ccjzbill.o /var/tmp//ccki9Mey.o /var/tmp//ccY02HQb.o /var/tmp//ccHfghPL.o /var/tmp//ccEm1hYz.o /var/tmp//ccGMl4QG.o /var/tmp//cc3JZ9H9.o /var/tmp//cck4M4kt.o -lstdc++ -lSystem -lgcc -lSystem
# Doesn't (4):
# ${TOOLCHAIN4} $ARCHS -lstdc++ ndk-stack.c ndk-stack-parser.c elff/dwarf_cu.cc elff/dwarf_die.cc elff/dwarf_utils.cc elff/elf_alloc.cc elff/elf_file.cc elff/elf_mapped_section.cc elff/elff_api.cc elff/mapfile.c regex/regcomp.c regex/regerror.c regex/regexec.c regex/regfree.c -o $OUT4/ndk-stack --sysroot $SDK -v >> $OUT4/output.txt 2>&1
#  /usr/llvm-gcc-4.2/bin/../libexec/gcc/i686-apple-darwin11/4.2.1/collect2 -dynamic -arch x86_64 -macosx_version_min 10.7.0 -weak_reference_mismatches non-weak -o /Volumes/Work/toolchain4/Darwin-apple-4/ndk-stack -lcrt1.10.6.o -L/usr/llvm-gcc-4.2/bin/../lib/gcc/i686-apple-darwin11/4.2.1/x86_64 -L/Developer/usr/llvm-gcc-4.2/lib/gcc/i686-apple-darwin11/4.2.1/x86_64 -L/Volumes/Work/toolchain4/sdks/MacOSX10.7.sdk/usr/lib/i686-apple-darwin11/4.2.1 -L/Volumes/Work/toolchain4/sdks/MacOSX10.7.sdk/usr/lib -L/usr/llvm-gcc-4.2/bin/../lib/gcc/i686-apple-darwin11/4.2.1 -L/usr/llvm-gcc-4.2/bin/../lib/gcc -L/Developer/usr/llvm-gcc-4.2/lib/gcc/i686-apple-darwin11/4.2.1 -L/usr/llvm-gcc-4.2/bin/../lib/gcc/i686-apple-darwin11/4.2.1/../../.. -L/Volumes/Work/toolchain4/sdks/MacOSX10.7.sdk/Developer/usr/llvm-gcc-4.2/lib/gcc/i686-apple-darwin11/4.2.1/../../.. -lstdc++ /var/tmp//ccroLj53.o /var/tmp//ccZSbOYY.o /var/tmp//cc4F7MMV.o /var/tmp//ccis0ot9.o /var/tmp//cclmKrhH.o /var/tmp//ccPFiYA1.o /var/tmp//ccW1Y0yO.o /var/tmp//cctDeziP.o /var/tmp//ccjUU4Dc.o /var/tmp//ccmCTjdu.o /var/tmp//ccy37yJB.o /var/tmp//ccUy8nhB.o /var/tmp//ccKU7YhX.o /var/tmp//ccTMM934.o -lstdc++ -lSystem -lgcc -lSystem
