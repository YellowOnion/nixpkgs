unpackPhase="unpackMojo"
# this unpacks icculus's mojosetup
# commonly used by Good Old Games (GoG)

unpackMojo() {
    runHook preUnpackMojo

    mkdir .tmp

    unzip -q "${src}" -d .tmp || [ $? -eq 1 ] && true # need this because unzip has code 1 for warnings with mojo files.

    mv ".tmp/${mojoGameLocation:=data/noarch/game/}"* ./

    rm -rf .tmp

    runHook postUnpackMojo
}
