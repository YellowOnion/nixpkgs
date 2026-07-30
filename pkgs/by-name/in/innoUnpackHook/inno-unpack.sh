unpackPhase="unpackInno"

unpackInno() {
    runHook preUnpackInno

    innoextract --silent --extract --exclude-temp "${src}"

    runHook postUnpackInno
}
