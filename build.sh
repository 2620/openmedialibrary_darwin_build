#!/bin/bash
cd `dirname $0`
set -e

BREW="/usr/local"
BASE="`pwd`"
NAME="platform_darwin64"
PREFIX="$BASE/$NAME"
# https://docs.travis-ci.com/user/reference/osx
OSXVERSION=10.11
pyversion=3.7.5

export PATH="$BREW/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/X11/bin"
export HOMEBREW_NO_ANALYTICS=1

function brew_install {
    pkg=$1
    brew list | grep -q $pkg || brew install $pkg
    brew outdated $pkg || brew upgrade $pkg
}

brew update
brew_install openssl
brew_install sqlite
brew_install xz
brew_install zlib
brew_install readline
brew_install libxml2
brew_install libxslt
brew_install unrar

ls -lah  $BREW/opt/zlib/lib || brew reinstall zlib || true
ls -lah  $BREW/opt/zlib/lib || true


# Python
CPPFLAGS="-I$BREW/opt/openssl/include/openssl"
LDFLAGS=""
for pkg in openssl sqlite readline xz zlib; do
    CPPFLAGS="$CPPFLAGS -I$BREW/opt/$pkg/include"
    LDFLAGS="$LDFLAGS -L$BREW/opt/$pkg/lib"
done
export CPPFLAGS
export LDFLAGS

mkdir -p "$PREFIX/lib"
for lib in \
    opt/libxml2/lib/libxml2.2.dylib \
    opt/libxslt/lib/libexslt.0.dylib \
    opt/libxslt/lib/libxslt.1.dylib \
    opt/openssl/lib/libcrypto.1.0.0.dylib \
    opt/openssl/lib/libssl.1.0.0.dylib \
    opt/readline/lib/libreadline.7.dylib \
    opt/readline/lib/libreadline.7.0.dylib \
    opt/sqlite/lib/libsqlite3.0.dylib \
    opt/xz/lib/liblzma.5.dylib \
    opt/zlib/lib/libz.1.dylib \
    opt/zlib/lib/libz.1.2.11.dylib \
    opt/unrar/lib/libunrar.dylib \
; do
    target="$PREFIX/lib/`basename "$lib"`"
    rm -f "$target"
    if [ -e "$BREW/$lib" ]; then
        cp -a "$BREW/$lib" "$target"
    else
        echo "!! $BREW/$lib missing"
        ls -la `dirname "$BREW/$lib"` || true
    fi
done

url="https://www.python.org/ftp/python/${pyversion}/Python-${pyversion}.tar.xz"
name=`basename $url .tar.xz`
tar=`basename $url`

test -e $tar || curl -O $url
test -e $name || tar xf $tar
cd $name
./configure MACOSX_DEPLOYMENT_TARGET=$OSXVERSION --with-openssl=$BREW/opt/openssl --prefix="$PREFIX"
make -j8
make altinstall

unset CPPFLAGS
unset LDFLAGS

ln -sf pip3.7 "$PREFIX/bin/pip"
ln -sf pip3.7 "$PREFIX/bin/pip3"
ln -sf python3.7 "$PREFIX/bin/python3"

PATH="$PREFIX/bin:$PATH"
hash -r 2>/dev/null

cd "$BASE"

curl https://git.0x2620.org/openmedialibrary.git/blob_plain/HEAD:/requirements.txt > requirements.txt
$PREFIX/bin/pip3 install -r requirements.txt

chmod -R +rw "$PREFIX/lib"
mkdir -p "$PREFIX/etc/openssl/certs"
cp $BREW/etc/openssl/cert.pem "$PREFIX/etc/openssl"

# cleanup
rm -rf \
    "$PREFIX/lib/python3.5/test" \
    "$PREFIX/bin/*.py" \
    "$PREFIX/bin/edsig" \
    "$PREFIX/bin/openssl" \
    "$PREFIX/etc/openssl/man" \
    "$PREFIX/bin/c_rehash" \
    "$PREFIX/bin/2to3-3.7" \
    "$PREFIX/bin/easy_install-3.7" \
    "$PREFIX/bin/idle3.7" \
    "$PREFIX/bin/pyvenv-3.7" \
    "$PREFIX/bin/c_rehash" \
    "$PREFIX/bin/pydoc3.7"

for bin in $PREFIX/bin/pip3.7 $PREFIX/bin/python3.7m-config; do
    sed "s#$PREFIX/bin/python3.7#/usr/bin/env python3.7#g" "$bin" > "$bin.t"
    mv "$bin.t" "$bin"
    chmod +x "$bin"
done

find "$PREFIX" -d -name "__pycache__" -type d -exec rm -r "{}" \;
find "$PREFIX" -name "*.pyc" -exec rm "{}" \;
find "$PREFIX" -name "*.a" -exec rm -f "{}" \;

for plib in \
    $PREFIX/lib/python3.7/site-packages/lxml/etree.cpython-37m-darwin.so \
    $PREFIX/lib/python3.7/site-packages/lxml/objectify.cpython-37m-darwin.so \
    $PREFIX/lib/python3.7/lib-dynload/_hashlib.cpython-37m-darwin.so \
    $PREFIX/lib/python3.7/lib-dynload/_lzma.cpython-37m-darwin.so \
    $PREFIX/lib/python3.7/lib-dynload/_sqlite3.cpython-37m-darwin.so \
    $PREFIX/lib/python3.7/lib-dynload/_ssl.cpython-37m-darwin.so \
    $PREFIX/lib/python3.7/lib-dynload/readline.cpython-37m-darwin.so \
    $PREFIX/lib/python3.7/lib-dynload/zlib.cpython-37m-darwin.so \
; do
    if [ -e "$plib" ]; then
        for lib in \
            $BREW/Cellar/libxslt/1.1.28_1/lib/libxslt.1.dylib \
            $BREW/Cellar/openssl/1.0.2d_1/lib/libcrypto.1.0.0.dylib \
            $BREW/opt/libxml2/lib/libxml2.2.dylib \
            $BREW/opt/libxslt/lib/libexslt.0.dylib \
            $BREW/opt/libxslt/lib/libxslt.1.dylib \
            $BREW/opt/openssl/lib/libcrypto.1.0.0.dylib \
            $BREW/opt/openssl/lib/libssl.1.0.0.dylib \
            $BREW/opt/readline/lib/libreadline.7.dylib \
            $BREW/opt/readline/lib/libreadline.7.0.dylib \
            $BREW/opt/sqlite/lib/libsqlite3.0.dylib \
            $BREW/opt/xz/lib/liblzma.5.dylib \
            $BREW/opt/zlib/lib/libz.1.dylib \
            $PREFIX/lib/libcrypto.1.0.0.dylib \
            $PREFIX/lib/libexslt.0.dylib \
            $PREFIX/lib/liblzma.5.dylib \
            $PREFIX/lib/libreadline.6.dylib \
            $PREFIX/lib/libreadline.6.3.dylib \
            $PREFIX/lib/libsqlite3.0.dylib \
            $PREFIX/lib/libssl.1.0.0.dylib \
            $PREFIX/lib/libxml2.2.dylib \
            $PREFIX/lib/libxslt.1.dylib \
            /usr/lib/libexslt.0.dylib \
            /usr/lib/libreadline.6.dylib \
            /usr/lib/libreadline.6.3.dylib \
            /usr/lib/libxml2.2.dylib \
            /usr/lib/libxslt.1.dylib \
        ; do
            name=`basename $lib`
            otool -L "$plib" | grep -q "$lib" && install_name_tool -change "$lib" "@executable_path/../lib/$name" "$plib"
        done
        otool -L "$plib"
    fi
done


cd ${BASE}
TOR_VERSION=8.5.5
TOR_DMG=TorBrowser-${TOR_VERSION}-osx64_en-US.dmg
curl -sLO https://dist.torproject.org/torbrowser/${TOR_VERSION}/${TOR_DMG}
hdiutil attach ${BASE}/${TOR_DMG}

TORPATH="/Volumes/Tor Browser"
ls -la "$TORPATH"
ls -la "$TORPATH/Tor Browser.app/Contents/MacOS/Tor/"
cp -r "$TORPATH/Tor Browser.app/Contents/MacOS/Tor/" "$PREFIX/tor"
rm -r "$PREFIX/tor/PluggableTransports"

hdiutil detach /dev/disk1

cat > "$PREFIX/tor/tor" << EOF
#!/bin/sh
# Compiled Python modules require a compatible Python, which means 32-bit 2.6.
export VERSIONER_PYTHON_VERSION=2.6
export DYLD_LIBRARY_PATH=.:\$DYLD_LIBRARY_PATH
# Set the current working directory to the directory containing this executable,
# so that pluggable transport executables can be given with relative paths. This
# works around a change in OS X 10.9, where the current working directory is
# otherwise set to "/" when an application bundle is started from Finder.
# https://trac.torproject.org/projects/tor/ticket/10030
cd "\$(dirname "\$0")"
if [ ! -f tor.real -a -d ../../../MacOS/Tor ]; then
  # On newer releases of Tor Browser, tor.real is in Contents/MacOS/Tor/.
  cd ../../../MacOS/Tor
fi
exec ./tor.real "\$@"
EOF
chmod +x "$PREFIX/tor/tor"

cd ${BASE}
tar czf ${PREFIX}.tar.gz ${NAME}
ls -lah ${PREFIX}.tar.gz
