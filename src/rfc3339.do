redo-ifchange rfc3339.nim
nim c -o:$3 rfc3339 1>&2
prove ./$3 1>&2
